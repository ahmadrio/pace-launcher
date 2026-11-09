import Foundation
import ServiceManagement

/// Launch at Login through SMAppService (no helper app needed).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registering from a build folder would point the login item at a
    /// copy that `make` deletes; only allow it for an installed bundle.
    static var isInstalled: Bool {
        let path = Bundle.main.bundlePath
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications").path
        return path.hasPrefix("/Applications/") || path.hasPrefix(userApps + "/")
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.app.notice("launch at login: \(enabled)")
        } catch {
            Log.app.error("launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
