import AppKit

@main
enum PACELauncherApp {
    static func main() {
        // Before anything reads a path: the settings store is created with
        // the app delegate, and creating the new data folder first would
        // leave DOT Launcher's data behind.
        AppPaths.migrateLegacyData()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar agent: no Dock icon, no main menu.
        app.setActivationPolicy(.accessory)
        MainMenu.install()
        // NSApplication.delegate is weak; keep ours alive for the app's lifetime.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
