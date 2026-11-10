import AppKit
import SwiftUI
import DOTLauncherCore

/// Default shortcuts copy another app's habit (Maccy, Rectangle) and are
/// therefore only active while that app is not running.
enum GatedHotKey {
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
    private var settingsWindow: SettingsWindowController?
    private var theme: ThemeController?
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
    private let scriptLibrary = ScriptLibrary()
    private var hud: HUDController?
    private var startScript: ((ScriptCommand, [String]) -> Void)?
    private var scriptActions: ScriptActions?
    private var autoExpand: AutoExpandController?
    private var sync: SyncController?

    /// With sync on, quitting writes one last clipboard backup first
    /// (at most 10 s, so quitting never hangs).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let sync, sync.wantsBackupOnQuit else { return .terminateNow }
        var replied = false
        let reply = {
            guard !replied else { return }
            replied = true
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        Task {
            await sync.backupOnQuit()
            reply()
        }
        Task {
            try? await Task.sleep(for: .seconds(10))
            reply()
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        notesWindow?.model.flush()
    }

    /// What each global shortcut does (set once at launch).
    private var shortcutActions: [ShortcutID: () -> Void] = [:]
    /// True while Settings records a shortcut: hotkeys stay released.
    private var shortcutsPaused = false
    private var clipboardMaintenance: ClipboardMaintenance?
    /// Blockers the user chose to ignore ("Enable anyway").
    private var overriddenBlockers: Set<GatedHotKey.Blocker> = []

    private static let maccy = GatedHotKey.Blocker(bundleID: "org.p0deje.Maccy", appName: "Maccy", group: "Clipboard shortcut")
    private static let rectangle = GatedHotKey.Blocker(bundleID: "com.knollsoft.Rectangle", appName: "Rectangle", group: "Window shortcuts")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Log.app.notice("DOT Launcher started, build \(version, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")

        let icons = IconCache()
        let indexer = AppIndexer()
        let windows = WindowManager()
        let model = LauncherModel()
        let theme = ThemeController(theme: settings.data.theme)
        self.theme = theme
        let panelController = PanelController(model: model, theme: theme)
        let hotKeys = HotKeyCenter()

        let windowCommands = CommandCatalog.windowCommands { action in
            windows.perform(action, on: panelController.targetApp)
        }
        // Every built-in command, rebuilt on each call so subtitles that
        // show state stay fresh. Search and command shortcuts share it.
        let commandList: () -> [LauncherCommand] = { [weak self] in
            [CommandCatalog.clipboardHistory(), CommandCatalog.translate(), CommandCatalog.aiChat(), CommandCatalog.aiChatHistory()] + windowCommands
                + CommandCatalog.snippetCommands(create: { self?.editSnippet(nil) })
                + CommandCatalog.noteCommands(open: { self?.notesWindow?.show() }, create: { self?.notesWindow?.showNew() })
                + CommandCatalog.scriptCommands(create: { self?.scriptLibrary.createTemplate() }, openFolder: { self?.scriptLibrary.openFolder() })
                + CommandCatalog.appCommands(
                    toggleIcon: { self?.toggleMenuBarIcon() },
                    iconVisible: { self?.settings.data.showMenuBarIcon ?? true },
                    openSettings: { self?.settingsWindow?.show() }
                )
        }
        let search = LauncherSearch(
            indexer: indexer, usage: Self.openUsageStore(), icons: icons,
            commands: commandList
        )
        let clipboardStore = Self.openClipboardStore()
        let clipboard = clipboardStore.map { ClipboardController(store: $0, icons: icons) }
        clipboard?.onNotice = { model.notice = $0 }
        clipboard?.onChange = { model.refresh() }

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
        snippets.onChange = { [weak self] in
            search.rebuild()
            self?.autoExpand?.reloadKeywords()
        }
        search.rebuild()
        model.handlers[.snippets] = LauncherModel.ModeHandler(
            results: { query in snippets.search(query).map(snippetRow) },
            actions: { [weak self] in
                [SecondaryAction(title: "New Snippet", shortcut: .command("n"), action: .run { self?.editSnippet(nil) })]
            }
        )
        self.snippets = snippets
        snippetEditor = SnippetEditorController(library: snippets, theme: theme)
        let autoExpand = AutoExpandController(library: snippets, settings: settings, pasteMonitor: { clipboard?.monitor })
        self.autoExpand = autoExpand
        autoExpand.refresh()

        let notes = NotesModel(store: Self.noteStore())
        let notesWindow = NotesWindowController(model: notes, theme: theme)
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
                let downloading = notes.downloadingCount > 0 ? [LauncherResult(
                    id: "notes-downloading",
                    title: "Downloading \(notes.downloadingCount) note(s) from iCloud…",
                    subtitle: "They appear here once they are on this Mac",
                    icon: .symbol("icloud.and.arrow.down"),
                    accessory: "iCloud",
                    actionTitle: "Refresh",
                    action: .stay { notes.reloadList() }
                )] : []
                return downloading + matches.map { note in
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

        // Script commands
        Task { await ShellEnvironment.load() }
        let scriptLibrary = self.scriptLibrary
        let session = ScriptSession()
        let hud = HUDController()
        self.hud = hud
        model.customContent[.scriptOutput] = { AnyView(ScriptOutputView(session: session)) }
        model.handlers[.scriptOutput] = LauncherModel.ModeHandler(
            actions: {
                guard let run = session.run, !run.output.isEmpty else { return [] }
                return [SecondaryAction(title: "Copy Output", shortcut: .command("c", shift: true), action: .stay {
                    TextPaster.copy(run.output)
                    model.notice = "Output copied"
                })]
            },
            queryChanged: { _ in },
            escape: {
                guard let run = session.run, run.isRunning else { return false }
                run.stop()
                return true
            }
        )
        let startScript: (ScriptCommand, [String]) -> Void = { script, arguments in
            let run = ScriptRunner.run(script, arguments: arguments)
            switch script.metadata.mode {
            case .fullOutput:
                session.run = run
                model.reset(to: .scriptOutput)
            case .compact, .silent, .inline:
                model.close()
                let compact = script.metadata.mode != .silent
                run.onFinish = { run in
                    if run.succeeded {
                        hud.show(compact ? run.lastLine : "✓ \(script.metadata.title)", isError: false)
                    } else {
                        hud.show(run.lastLine.isEmpty ? "\(script.metadata.title) failed" : run.lastLine, isError: true)
                    }
                }
            }
        }
        self.startScript = startScript
        search.scripts = { scriptLibrary.scripts }
        let argumentForm = ScriptArgumentForm()
        let scriptActions = ScriptActions(library: scriptLibrary, form: argumentForm, model: model, start: startScript)
        self.scriptActions = scriptActions
        search.scriptRow = { script in scriptActions.row(for: script) }
        scriptActions.onInlineUpdate = {
            search.rebuild()
            if panelController.isVisible, model.mode == .root { model.refresh() }
        }
        model.customContent[.scriptArguments] = {
            AnyView(ScriptArgumentsView(form: argumentForm, submit: { scriptActions.submitArguments() }, cancel: { model.reset(to: .root) }))
        }
        model.handlers[.scriptArguments] = LauncherModel.ModeHandler(
            submit: { scriptActions.submitArguments() },
            submitTitle: "Run",
            queryChanged: { _ in }
        )
        scriptLibrary.onChange = { [weak self] in
            search.rebuild()
            self?.applyShortcuts()
        }

        model.search = { query in search.results(for: query) }
        model.handlers[.clipboard] = LauncherModel.ModeHandler(
            results: { query in await clipboard?.results(for: query) ?? [] },
            preview: { result in clipboard?.preview(for: result) }
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

        // Quicklinks: rows in root search, and a mode that asks for the text.
        var activeQuicklink: Quicklink?
        let openQuicklink: (Quicklink, String) -> Void = { [weak self] link, text in
            if !QuicklinkOpener.open(link, query: text) {
                self?.hud?.show("Could not open this quicklink.", isError: true)
            }
        }
        search.quicklinks = { [weak self] in self?.settings.data.quicklinks ?? [] }
        search.openQuicklink = openQuicklink
        search.enterQuicklink = { link in
            activeQuicklink = link
            model.reset(to: .quicklink)
        }
        model.handlers[.quicklink] = LauncherModel.ModeHandler(
            results: { query in
                guard let link = activeQuicklink else { return [] }
                let text = query.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else {
                    return [LauncherResult(
                        id: "quicklink-mode", title: "Type to search \(link.name)", subtitle: LauncherSearch.quicklinkSubtitle(for: link),
                        icon: .symbol("link"), accessory: "Quicklink", actionTitle: "", action: .stay {}
                    )]
                }
                return [LauncherResult(
                    id: "quicklink-mode", title: "Search \(link.name) for “\(text)”", subtitle: LauncherSearch.quicklinkSubtitle(for: link),
                    icon: .symbol("link"), accessory: "Quicklink", actionTitle: "Open",
                    action: .run { openQuicklink(link, text) }
                )]
            }
        )

        let chat = AIChatController(translator: translator, store: Self.openChatStore())
        /// True when AI Chats was opened with ⌘Y, so Esc goes back to the chat.
        var chatHistoryFromAI = false
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
                actions.append(SecondaryAction(title: "History", shortcut: .command("y"), action: .stay {
                    // Esc in the history then returns to this chat. Set after
                    // the reset: entering the mode clears it.
                    model.reset(to: .chatHistory)
                    chatHistoryFromAI = true
                }))
                return actions
            },
            escape: { chat.cancel() },
            entered: { chat.prewarm() }
        )
        let chatRelative = RelativeDateTimeFormatter()
        chatRelative.unitsStyle = .abbreviated
        model.handlers[.chatHistory] = LauncherModel.ModeHandler(
            results: { query in
                await chat.history(matching: query).map { summary in
                    LauncherResult(
                        id: "chat:" + summary.id.uuidString,
                        title: summary.title,
                        subtitle: "\(summary.messageCount) messages · \(chatRelative.localizedString(for: summary.updatedAt, relativeTo: .now))",
                        icon: .symbol("bubble.left.and.bubble.right"),
                        accessory: "Chat",
                        actionTitle: "Open",
                        action: .stay {
                            chatHistoryFromAI = false
                            Task {
                                await chat.open(summary.id)
                                model.reset(to: .ai)
                            }
                        },
                        secondaryActions: [
                            // Deleting is async: refresh once it is done.
                            SecondaryAction(title: "Delete", shortcut: .delete, confirm: true, action: .stay {
                                Task {
                                    await chat.delete(summary.id)
                                    model.refresh()
                                }
                            }),
                        ]
                    )
                }
            },
            actions: {
                [SecondaryAction(
                    title: "Delete All Chats",
                    shortcut: KeyShortcut(key: "\u{7f}", modifiers: [.command, .shift]),
                    confirm: true,
                    action: .stay {
                        Task {
                            await chat.deleteAll()
                            model.refresh()
                        }
                    }
                )]
            },
            escape: {
                guard chatHistoryFromAI else { return false }
                chatHistoryFromAI = false
                model.reset(to: .ai)
                return true
            },
            // Any other way in (the AI Chats command) goes back to the root.
            entered: { chatHistoryFromAI = false }
        )
        self.chat = chat
        indexer.onUpdate = {
            search.rebuild()
            if panelController.isVisible { model.refresh() }
        }
        let rates = RatesService()
        search.rates = rates
        rates.onUpdate = {
            if panelController.isVisible, model.mode == .root { model.refresh() }
        }
        let sync = SyncController(
            settings: settings, clipboard: clipboardStore,
            beforeMove: { notes.flush() },
            afterMove: { [weak self] in
                snippets.switchStore(SnippetStore(directory: AppPaths.snippetsDirectory))
                notes.switchStore(Self.noteStore())
                scriptLibrary.reload()
                self?.settings.reload()
            }
        )
        self.sync = sync
        notes.onPlaceholders = { sync.downloadPlaceholders() }
        panelController.onShow = { [weak self] in
            chatHistoryFromAI = false
            indexer.refreshIfStale()
            sync.downloadPlaceholders()
            self?.settings.reloadIfDownloaded()
            // Snippet files can change outside the app (another editor,
            // a synced folder); re-read them on every open. This also
            // rebuilds search through snippets.onChange.
            snippets.reload()
            scriptLibrary.reload()
            scriptActions.refreshInline()
        }
        indexer.refreshIfStale()
        clipboard?.start()

        shortcutActions[.launcher] = { panelController.toggle() }
        shortcutActions[.clipboardHistory] = { panelController.toggle(mode: .clipboard) }
        for action in WindowAction.allCases {
            // Hotkeys act on whatever app is frontmost right now.
            shortcutActions[.window(action)] = { windows.perform(action, on: nil) }
        }
        for command in CommandShortcut.allCases {
            // The same as choosing the command in the launcher: modes open
            // the panel in that mode, the rest run right away.
            shortcutActions[.command(command)] = {
                guard let found = commandList().first(where: { $0.id == command.rawValue }) else {
                    Log.hotkeys.error("no launcher command \(command.rawValue, privacy: .public)")
                    return
                }
                switch found.action {
                case .enter(let mode): panelController.toggle(mode: mode)
                case .run(let work), .stay(let work): work()
                }
            }
        }

        self.indexer = indexer
        self.search = search
        self.clipboard = clipboard
        self.windows = windows
        self.panelController = panelController
        self.hotKeys = hotKeys

        // Script shortcuts need the scripts before the first panel opens.
        scriptLibrary.reload()
        applyShortcuts()
        watchBlockingApps()

        statusMenu = StatusMenuController(
            hotKeys: hotKeys,
            blockedGroups: { [weak self] in self?.blockedBlockers() ?? [] },
            clipboardAccess: { clipboard?.monitor.access },
            openLauncher: { panelController.show() },
            enableAnyway: { [weak self] blocker in
                self?.overriddenBlockers.insert(blocker)
                self?.applyShortcuts()
            },
            hideIcon: { [weak self] in self?.toggleMenuBarIcon() },
            openSettings: { [weak self] in self?.settingsWindow?.show() },
            autoExpandStatus: { autoExpand.status }
        )
        statusMenu?.setIconVisible(settings.data.showMenuBarIcon)

        let recorder = ShortcutRecorder(settings: settings, hotKeys: hotKeys) { [weak self] paused in
            guard let self else { return }
            self.shortcutsPaused = paused
            if paused { hotKeys.unregisterAll() } else { self.applyShortcuts() }
        }
        recorder.titleOf = { [weak self] id in self?.shortcut(for: id)?.title ?? id.title }
        let maintenance = ClipboardMaintenance(store: clipboardStore, settings: settings)
        maintenance.onChange = {
            if panelController.isVisible, model.mode == .clipboard { model.refresh() }
        }
        maintenance.start()
        self.clipboardMaintenance = maintenance
        let settingsWindow = SettingsWindowController(settings: settings, scripts: scriptLibrary, autoExpand: autoExpand, sync: sync, shortcuts: recorder, clipboard: maintenance)
        self.settingsWindow = settingsWindow
        panelController.canHideApp = { !settingsWindow.isVisible }
        settings.onChange = { [weak self] old, new in
            guard let self else { return }
            if old.autoExpandEnabled != new.autoExpandEnabled {
                self.autoExpand?.refresh()
            }
            if old.theme != new.theme {
                self.theme?.update(new.theme)
            }
            if old.showMenuBarIcon != new.showMenuBarIcon {
                self.statusMenu?.setIconVisible(new.showMenuBarIcon)
                self.search?.rebuild()
            }
            if !old.includeClipboardInBackup, new.includeClipboardInBackup {
                Task { await self.sync?.backupIfDue() }
            }
            if old.quicklinks != new.quicklinks {
                self.search?.rebuild()
            }
            if old.shortcuts != new.shortcuts {
                self.applyShortcuts()
            }
            if old.clipboardRetention != new.clipboardRetention {
                self.clipboardMaintenance?.prune()
            }
        }
        sync.start()
    }

    /// Notes in the active data folder; deleted notes go to the Trash.
    private static func noteStore() -> NoteStore {
        NoteStore(directory: AppPaths.notesDirectory) { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    @objc func showSettings(_ sender: Any?) {
        panelController?.hide()
        settingsWindow?.show()
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
        // settings.onChange updates the status item and search.
        settings.data.showMenuBarIcon.toggle()
        Log.app.notice("menu bar icon \(self.settings.data.showMenuBarIcon ? "shown" : "hidden", privacy: .public)")
    }

    private func isRunning(_ blocker: GatedHotKey.Blocker) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: blocker.bundleID).isEmpty
    }

    private static func blocker(for id: ShortcutID) -> GatedHotKey.Blocker? {
        switch id {
        case .launcher, .command, .script: nil
        case .clipboardHistory: maccy
        case .window: rectangle
        }
    }

    /// The app a shortcut is stepping aside for right now, if any.
    private func activeBlocker(for id: ShortcutID, combo: KeyCombo) -> GatedHotKey.Blocker? {
        guard let blocker = Self.blocker(for: id), Shortcuts.followsOtherAppHabit(id, combo),
              isRunning(blocker), !overriddenBlockers.contains(blocker)
        else { return nil }
        return blocker
    }

    /// Blockers currently switching shortcuts off.
    private func blockedBlockers() -> [GatedHotKey.Blocker] {
        var result: [GatedHotKey.Blocker] = []
        for (id, combo) in Shortcuts.resolve(settings.data.shortcuts) {
            if let blocker = activeBlocker(for: id, combo: combo), !result.contains(blocker) {
                result.append(blocker)
            }
        }
        return result
    }

    /// Registers the shortcuts from settings.json: removed ones are
    /// released, changed ones re-registered, and default ones step aside
    /// while Maccy or Rectangle runs.
    private func applyShortcuts() {
        guard let hotKeys, !shortcutsPaused else { return }
        let resolved = Shortcuts.resolve(settings.data.shortcuts)
        var registered: [ShortcutID: KeyCombo] = [:]
        var held: [ShortcutID] = []
        for entry in hotKeys.entries {
            guard let id = ShortcutID(rawValue: entry.name) else { continue }
            held.append(id)
            // A renamed script re-registers, so menus show its new title.
            let working = entry.status == .registered || entry.status == .shared
            if working, shortcut(for: id)?.title == entry.title { registered[id] = entry.combo }
        }
        var desired: [ShortcutID: KeyCombo] = [:]
        var gated: [(id: ShortcutID, combo: KeyCombo, blocker: GatedHotKey.Blocker)] = []
        for id in Shortcuts.ordered(resolved.keys) {
            // A script that is not found keeps its saved shortcut but holds no combo.
            guard let combo = resolved[id], shortcut(for: id) != nil else { continue }
            if let blocker = activeBlocker(for: id, combo: combo) {
                gated.append((id, combo, blocker))
            } else {
                desired[id] = combo
            }
        }

        // Release every changed combo before registering new ones, so a
        // swap (A↔B) never tries to take a combo that is still held.
        let plan = Shortcuts.registrationPlan(registered: registered, desired: desired)
        for id in plan.release { hotKeys.unregister(name: id.rawValue) }
        let gatedIDs = Set(gated.map(\.id))
        for id in held where desired[id] == nil && !gatedIDs.contains(id) {
            hotKeys.unregister(name: id.rawValue)
        }
        for entry in gated {
            hotKeys.markDisabled(entry.combo, name: entry.id.rawValue, title: entry.id.title, reason: "off while \(entry.blocker.appName) runs")
        }
        for id in plan.register {
            guard let combo = desired[id], let shortcut = shortcut(for: id) else { continue }
            hotKeys.register(combo, name: id.rawValue, title: shortcut.title, action: shortcut.action)
        }
    }

    /// What a shortcut is called and does; nil for a script that is not
    /// found (its shortcut stays saved, but nothing is registered).
    private func shortcut(for id: ShortcutID) -> (title: String, action: () -> Void)? {
        if case .script(let key) = id {
            guard let script = ScriptShortcut.script(forKey: key, in: scriptLibrary.scripts, mainFolder: AppPaths.scriptsDirectory) else { return nil }
            return (script.metadata.title, { [weak self] in self?.runScriptShortcut(key) })
        }
        guard let action = shortcutActions[id] else { return nil }
        return (id.title, action)
    }

    /// A script shortcut: re-reads the scripts (mode and arguments may have
    /// changed), then does what choosing the script in the launcher does.
    private func runScriptShortcut(_ key: String) {
        let id = ShortcutID.script(key)
        let comboText = hotKeys?.combo(of: id.rawValue)?.displayString ?? "the shortcut"
        scriptLibrary.reload()
        guard let script = ScriptShortcut.script(forKey: key, in: scriptLibrary.scripts, mainFolder: AppPaths.scriptsDirectory) else {
            hud?.show("Script not found: \(id.title)", isError: true)
            return
        }
        Log.hotkeys.info("script shortcut: \(script.metadata.title, privacy: .public)")
        scriptActions?.runFromShortcut(
            script, comboText: comboText,
            showPanel: { [weak self] in self?.panelController?.show() },
            notify: { [weak self] text, isError in self?.hud?.show(text, isError: isError) }
        )
    }

    /// Re-applies gated shortcuts when Maccy or Rectangle starts or quits.
    private func watchBlockingApps() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            Task { [weak self] in
                for await notification in center.notifications(named: name) {
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    guard let self, let bundleID = app?.bundleIdentifier,
                          [Self.maccy, Self.rectangle].contains(where: { $0.bundleID == bundleID })
                    else { continue }
                    self.applyShortcuts()
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

    private static func openChatStore() -> ChatStore? {
        do {
            return try ChatStore(path: AppPaths.chatDatabase.path)
        } catch {
            Log.app.error("chat store unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func openClipboardStore() -> ClipboardStore? {
        do {
            return try ClipboardStore(path: AppPaths.clipboardDatabase.path, imagesDirectory: AppPaths.clipboardImagesDirectory)
        } catch {
            Log.clipboard.error("clipboard store unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
