import AppKit
import SwiftUI
import DOTLauncherCore

/// A shortcut that copies another app's habit (Maccy, Rectangle) and is
/// therefore only active while that app is not running.
struct GatedHotKey {
    let name: String
    let combo: KeyCombo
    let blocker: Blocker
    let action: () -> Void

    struct Blocker: Hashable {
        let bundleID: String
        let appName: String
        /// How the menu names the shortcuts this app blocks.
        let group: String
    }
}

/// Composition root: creates the services and wires them together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// settings.json in the active data folder.
    let settings = SettingsStore()
    private var statusMenu: StatusMenuController?
    private var panelController: PanelController?
    private var hotKeys: HotKeyCenter?
    private var indexer: AppIndexer?
    private var search: LauncherSearch?
    private var clipboard: ClipboardController?
    private var windows: WindowManager?
    private var translator: Translator?
    private var chat: AIChatController?
    private var snippets: SnippetLibrary?
    private var snippetEditor: SnippetEditorController?
    private var notesWindow: NotesWindowController?

    func applicationWillTerminate(_ notification: Notification) {
        notesWindow?.model.flush()
    }

    private var gatedHotKeys: [GatedHotKey] = []
    /// Blockers the user chose to ignore ("Enable anyway").
    private var overriddenBlockers: Set<GatedHotKey.Blocker> = []

    static let launcherHotKey = KeyCombo("opt+space")!
    private static let maccy = GatedHotKey.Blocker(bundleID: "org.p0deje.Maccy", appName: "Maccy", group: "Clipboard shortcut")
    private static let rectangle = GatedHotKey.Blocker(bundleID: "com.knollsoft.Rectangle", appName: "Rectangle", group: "Window shortcuts")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Log.app.notice("DOT Launcher started, build \(version, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")

        let icons = IconCache()
        let indexer = AppIndexer()
        let windows = WindowManager()
        let model = LauncherModel()
        let panelController = PanelController(model: model)
        let hotKeys = HotKeyCenter()

        let windowCommands = CommandCatalog.windowCommands { action in
            windows.perform(action, on: panelController.targetApp)
        }
        let search = LauncherSearch(
            indexer: indexer, usage: Self.openUsageStore(), icons: icons,
            commands: { [weak self] in
                [CommandCatalog.clipboardHistory(), CommandCatalog.translate(), CommandCatalog.aiChat()] + windowCommands
                    + CommandCatalog.snippetCommands(create: { self?.editSnippet(nil) })
                    + CommandCatalog.noteCommands(open: { self?.notesWindow?.show() }, create: { self?.notesWindow?.showNew() })
                    + CommandCatalog.appCommands(
                        toggleIcon: { self?.toggleMenuBarIcon() },
                        iconVisible: { self?.settings.data.showMenuBarIcon ?? true }
                    )
            }
        )
        let clipboard = Self.openClipboardStore().map { ClipboardController(store: $0, icons: icons) }

        let snippets = SnippetLibrary(store: SnippetStore(directory: AppPaths.snippetsDirectory))
        let snippetRow: (Snippet) -> LauncherResult = { [weak self] snippet in
            let firstLine = snippet.content.split(whereSeparator: \.isNewline).first.map(String.init)
            let details = [snippet.keyword, firstLine].compactMap { $0 }.filter { !$0.isEmpty }
            return LauncherResult(
                id: "snippet-row:" + snippet.id.uuidString,
                title: snippet.name,
                subtitle: details.joined(separator: " · "),
                icon: .symbol("text.quote"),
                accessory: "Snippet",
                actionTitle: "Paste",
                action: .run { snippets.paste(snippet, monitor: clipboard?.monitor) },
                secondaryActions: [
                    SecondaryAction(title: "Edit", shortcut: .command("e"), action: .run { self?.editSnippet(snippet) }),
                    SecondaryAction(title: "Delete", shortcut: .delete, confirm: true, action: .stay { snippets.delete(snippet.id) }),
                ]
            )
        }
        search.snippets = { snippets.snippets }
        search.snippetRow = snippetRow
        snippets.onChange = { search.rebuild() }
        search.rebuild()
        model.handlers[.snippets] = LauncherModel.ModeHandler(
            results: { query in snippets.search(query).map(snippetRow) },
            actions: { [weak self] in
                [SecondaryAction(title: "New Snippet", shortcut: .command("n"), action: .run { self?.editSnippet(nil) })]
            }
        )
        self.snippets = snippets
        snippetEditor = SnippetEditorController(library: snippets)

        let notes = NotesModel(store: NoteStore(directory: AppPaths.notesDirectory) { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        })
        let notesWindow = NotesWindowController(model: notes)
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        model.handlers[.notes] = LauncherModel.ModeHandler(
            results: { query in
                notes.reloadList()
                let query = query.trimmingCharacters(in: .whitespaces)
                let matches = query.isEmpty ? notes.summaries : notes.summaries.filter {
                    FuzzyMatcher.score(query, in: $0.title) != nil
                        || notes.body(of: $0.id).localizedCaseInsensitiveContains(query)
                }
                return matches.map { note in
                    LauncherResult(
                        id: "note:" + note.id.uuidString,
                        title: note.title,
                        subtitle: [note.preview, relative.localizedString(for: note.modifiedAt, relativeTo: .now)]
                            .filter { !$0.isEmpty }.joined(separator: " · "),
                        icon: .symbol("note.text"),
                        accessory: "Note",
                        actionTitle: "Open",
                        action: .run { notesWindow.show(note: note.id) },
                        secondaryActions: [
                            SecondaryAction(title: "Delete", shortcut: .delete, confirm: true, action: .stay { notes.trash(note.id) }),
                        ]
                    )
                }
            }
        )
        self.notesWindow = notesWindow

        model.search = { query in search.results(for: query) }
        model.handlers[.clipboard] = LauncherModel.ModeHandler(
            results: { query in await clipboard?.results(for: query) ?? [] }
        )

        let translator = Translator()
        let translate = TranslateController(translator: translator)
        model.customContent[.translate] = { AnyView(TranslateView(controller: translate)) }
        model.handlers[.translate] = LauncherModel.ModeHandler(
            submit: {
                // Only a finished translation of the current text; while a
                // newer one is running, the shown output is stale.
                guard translate.status == .done, !translate.output.isEmpty else {
                    if translate.status == .translating { model.notice = "Still translating…" }
                    return
                }
                TextPaster.copy(translate.output)
                model.close()
            },
            submitTitle: "Copy",
            actions: {
                var actions = [
                    SecondaryAction(title: "Swap", shortcut: .command("l"), action: .stay { translate.swap() }),
                ]
                if translate.status == .done, !translate.output.isEmpty {
                    let output = translate.output
                    actions.insert(SecondaryAction(title: "Paste", shortcut: .command("\r"), action: .run {
                        TextPaster.paste(output, monitor: clipboard?.monitor)
                    }), at: 0)
                }
                return actions
            },
            queryChanged: { translate.update($0) },
            entered: { translate.reset() }
        )
        self.translator = translator

        let chat = AIChatController(translator: translator)
        let askAI: (String) -> Void = { query in
            model.reset(to: .ai)
            chat.send(query)
        }
        search.askAI = askAI
        model.onTab = {
            guard model.mode == .root, !model.query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            askAI(model.query)
        }
        model.customContent[.ai] = { AnyView(ChatView(chat: chat)) }
        model.handlers[.ai] = LauncherModel.ModeHandler(
            submit: {
                guard !chat.isGenerating, !model.query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                chat.send(model.query)
                model.query = ""
            },
            submitTitle: "Send",
            actions: {
                var actions = [
                    SecondaryAction(title: "New Chat", shortcut: .command("n"), action: .stay { chat.reset() }),
                ]
                if let answer = chat.lastAnswer {
                    actions.append(SecondaryAction(title: "Copy Answer", shortcut: .command("c", shift: true), action: .stay {
                        TextPaster.copy(answer)
                        model.notice = "Answer copied"
                    }))
                    actions.append(SecondaryAction(title: "Paste Answer", shortcut: .command("\r"), action: .run {
                        TextPaster.paste(answer, monitor: clipboard?.monitor)
                    }))
                }
                if chat.lastAnswerHasOriginal {
                    actions.append(SecondaryAction(
                        title: chat.showOriginal ? "Show Translation" : "Show Original",
                        shortcut: .command("o", shift: true),
                        action: .stay { chat.showOriginal.toggle() }
                    ))
                }
                return actions
            },
            escape: { chat.cancel() },
            entered: { chat.prewarm() }
        )
        self.chat = chat
        indexer.onUpdate = {
            search.rebuild()
            if panelController.isVisible { model.refresh() }
        }
        panelController.onShow = {
            indexer.refreshIfStale()
            // Snippet files can change outside the app (another editor,
            // a synced folder); re-read them on every open. This also
            // rebuilds search through snippets.onChange.
            snippets.reload()
        }
        indexer.refreshIfStale()
        clipboard?.start()

        hotKeys.register(Self.launcherHotKey, name: "Open DOT Launcher") {
            panelController.toggle()
        }
        gatedHotKeys = [
            GatedHotKey(name: "Clipboard History", combo: KeyCombo("shift+opt+c")!, blocker: Self.maccy) {
                panelController.toggle(mode: .clipboard)
            },
        ]
        for action in WindowAction.allCases {
            guard let combo = action.defaultHotKey.flatMap(KeyCombo.init) else { continue }
            gatedHotKeys.append(GatedHotKey(name: action.title, combo: combo, blocker: Self.rectangle) {
                // Hotkeys act on whatever app is frontmost right now.
                windows.perform(action, on: nil)
            })
        }

        self.indexer = indexer
        self.search = search
        self.clipboard = clipboard
        self.windows = windows
        self.panelController = panelController
        self.hotKeys = hotKeys

        applyGatedHotKeys()
        watchBlockingApps()

        statusMenu = StatusMenuController(
            hotKeys: hotKeys,
            blockedGroups: { [weak self] in self?.blockedBlockers() ?? [] },
            clipboardAccess: { clipboard?.monitor.access },
            openLauncher: { panelController.show() },
            enableAnyway: { [weak self] blocker in
                self?.overriddenBlockers.insert(blocker)
                self?.applyGatedHotKeys()
            },
            hideIcon: { [weak self] in self?.toggleMenuBarIcon() }
        )
        statusMenu?.setIconVisible(settings.data.showMenuBarIcon)
    }

    /// Opening the app again while it runs (Finder, Spotlight, `open`)
    /// shows the launcher, so a hidden menu bar icon never strands it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show()
        return false
    }

    /// Opens the snippet editor (nil = new snippet), hiding the launcher.
    private func editSnippet(_ snippet: Snippet?) {
        panelController?.hide()
        snippetEditor?.open(snippet)
    }

    private func toggleMenuBarIcon() {
        settings.data.showMenuBarIcon.toggle()
        statusMenu?.setIconVisible(settings.data.showMenuBarIcon)
        search?.rebuild()
        Log.app.notice("menu bar icon \(self.settings.data.showMenuBarIcon ? "shown" : "hidden", privacy: .public)")
    }

    private func isRunning(_ blocker: GatedHotKey.Blocker) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: blocker.bundleID).isEmpty
    }

    /// Blockers currently switching shortcuts off.
    private func blockedBlockers() -> [GatedHotKey.Blocker] {
        var seen: Set<GatedHotKey.Blocker> = []
        return gatedHotKeys.map(\.blocker).filter { blocker in
            guard !seen.contains(blocker) else { return false }
            seen.insert(blocker)
            return isRunning(blocker) && !overriddenBlockers.contains(blocker)
        }
    }

    /// Registers each gated shortcut unless its look-alike app is running.
    private func applyGatedHotKeys() {
        guard let hotKeys else { return }
        for gated in gatedHotKeys {
            if isRunning(gated.blocker) && !overriddenBlockers.contains(gated.blocker) {
                hotKeys.markDisabled(gated.combo, name: gated.name, reason: "off while \(gated.blocker.appName) runs")
            } else if hotKeys.status(of: gated.name) != .registered {
                hotKeys.register(gated.combo, name: gated.name, action: gated.action)
            }
        }
    }

    /// Re-applies gated shortcuts when Maccy or Rectangle starts or quits.
    private func watchBlockingApps() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            Task { [weak self] in
                for await notification in center.notifications(named: name) {
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    guard let self, let bundleID = app?.bundleIdentifier,
                          self.gatedHotKeys.contains(where: { $0.blocker.bundleID == bundleID })
                    else { continue }
                    self.applyGatedHotKeys()
                }
            }
        }
    }

    private static func openUsageStore() -> UsageStore? {
        do {
            return try UsageStore(database: SQLiteDatabase(path: AppPaths.launcherDatabase.path))
        } catch {
            Log.app.error("usage store unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func openClipboardStore() -> ClipboardStore? {
        do {
            return try ClipboardStore(path: AppPaths.clipboardDatabase.path)
        } catch {
            Log.clipboard.error("clipboard store unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
