import AppKit
import DOTLauncherCore

enum AppLauncher {
    static func open(_ entry: AppEntry) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let url = URL(filePath: entry.path)

        Task {
            do {
                let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                Log.apps.info("opened \(entry.name, privacy: .public) (pid \(app.processIdentifier))")
            } catch {
                Log.apps.error("could not open \(entry.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
