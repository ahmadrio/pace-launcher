import AppKit
import DOTLauncherCore

/// Composition root: creates the services and wires them together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenuController?
    private var panelController: PanelController?
    private var hotKeys: HotKeyCenter?

    static let launcherHotKey = KeyCombo("opt+space")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Log.app.notice("DOT Launcher started, build \(version, privacy: .public), bundle \(Bundle.main.bundlePath, privacy: .public)")

        let model = LauncherModel()
        let panelController = PanelController(model: model)
        let hotKeys = HotKeyCenter()

        hotKeys.register(Self.launcherHotKey, name: "Open DOT Launcher") {
            panelController.toggle()
        }

        self.panelController = panelController
        self.hotKeys = hotKeys
        statusMenu = StatusMenuController(hotKeys: hotKeys) {
            panelController.show()
        }
    }
}
