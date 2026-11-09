import AppKit
import DOTLauncherCore

/// A shortcut that copies another app's habit (Maccy, Rectangle) and is
/// therefore only active while that app is not running.
struct GatedHotKey {
    let name: String
    let combo: KeyCombo
    let blockingBundleID: String
    let blockingAppName: String
    let action: () -> Void
}

/// Composition root: creates the services and wires them together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?
    private var panelController: PanelController?
    private var hotKeys: HotKeyCenter?
    private var indexer: AppIndexer?
    private var search: LauncherSearch?
    private var clipboard: ClipboardController?

    private var gatedHotKeys: [GatedHotKey] = []
    /// Gated shortcuts the user chose to enable even though the other app runs.
    private var forcedHotKeys: Set<String> = []

    static let launcherHotKey = KeyCombo("opt+space")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Log.app.notice("DOT Launcher started, build \(version, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")

        let icons = IconCache()
        let indexer = AppIndexer()
        let search = LauncherSearch(
            indexer: indexer, usage: Self.openUsageStore(), icons: icons,
            commands: [CommandCatalog.clipboardHistory()]
        )
        let clipboard = Self.openClipboardStore().map { ClipboardController(store: $0, icons: icons) }
        let model = LauncherModel()
        let panelController = PanelController(model: model)
        let hotKeys = HotKeyCenter()

        model.search = { query in search.results(for: query) }
        model.clipboardSearch = { query in await clipboard?.results(for: query) ?? [] }
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
            GatedHotKey(
                name: "Clipboard History", combo: KeyCombo("shift+opt+c")!,
                blockingBundleID: "org.p0deje.Maccy", blockingAppName: "Maccy",
                action: { panelController.toggle(mode: .clipboard) }
            ),
        ]

        self.indexer = indexer
        self.search = search
        self.clipboard = clipboard
        self.panelController = panelController
        self.hotKeys = hotKeys

        applyGatedHotKeys()
        watchBlockingApps()

        statusMenu = StatusMenuController(
            hotKeys: hotKeys,
            clipboardAccess: { clipboard?.monitor.access },
            openLauncher: { panelController.show() },
            enableAnyway: { [weak self] name in
                self?.forcedHotKeys.insert(name)
                self?.applyGatedHotKeys()
            }
        )
    }

    /// Registers each gated shortcut unless its look-alike app is running.
    private func applyGatedHotKeys() {
        guard let hotKeys else { return }
        for gated in gatedHotKeys {
            let blocked = !NSRunningApplication.runningApplications(withBundleIdentifier: gated.blockingBundleID).isEmpty
            if blocked && !forcedHotKeys.contains(gated.name) {
                hotKeys.markDisabled(gated.combo, name: gated.name, reason: "off while \(gated.blockingAppName) runs")
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
                          self.gatedHotKeys.contains(where: { $0.blockingBundleID == bundleID })
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
