import AppKit
import DOTLauncherCore

/// Composition root: creates the services and wires them together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?
    private var panelController: PanelController?
    private var hotKeys: HotKeyCenter?
    private var indexer: AppIndexer?
    private var search: LauncherSearch?

    static let launcherHotKey = KeyCombo("opt+space")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Log.app.notice("DOT Launcher started, build \(version, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")

        let indexer = AppIndexer()
        let search = LauncherSearch(indexer: indexer, usage: Self.openUsageStore())
        let model = LauncherModel()
        let panelController = PanelController(model: model)
        let hotKeys = HotKeyCenter()

        model.search = { query in search.results(for: query) }
        indexer.onUpdate = {
            search.rebuild()
            if panelController.isVisible { model.refresh() }
        }
        panelController.onShow = { indexer.refreshIfStale() }
        indexer.refreshIfStale()

        hotKeys.register(Self.launcherHotKey, name: "Open DOT Launcher") {
            panelController.toggle()
        }

        self.indexer = indexer
        self.search = search
        self.panelController = panelController
        self.hotKeys = hotKeys
        statusMenu = StatusMenuController(hotKeys: hotKeys) {
            panelController.show()
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
}
