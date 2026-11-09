import AppKit

@main
enum DOTLauncherApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar agent: no Dock icon, no main menu.
        app.setActivationPolicy(.accessory)
        // NSApplication.delegate is weak; keep ours alive for the app's lifetime.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
