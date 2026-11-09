import AppKit
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
    private var statusMenu: StatusMenuController?
    private var panelController: PanelController?
    private var hotKeys: HotKeyCenter?
    private var indexer: AppIndexer?
    private var search: LauncherSearch?
    private var clipboard: ClipboardController?
    private var windows: WindowManager?

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
            commands: [CommandCatalog.clipboardHistory()] + windowCommands
        )
        let clipboard = Self.openClipboardStore().map { ClipboardController(store: $0, icons: icons) }

        model.search = { query in search.results(for: query) }
        model.handlers[.clipboard] = LauncherModel.ModeHandler(
            results: { query in await clipboard?.results(for: query) ?? [] }
        )
        indexer.onUpdate = {
            search.rebuild()
            if panelController.isVisible { model.refresh() }
        }
        panelController.onShow = { indexer.refreshIfStale() }
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
            }
        )
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
