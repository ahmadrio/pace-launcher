import AppKit
import PACELauncherCore

/// The answer to "Check for Updates", as a standard dialog.
enum UpdateAlert {
    static func show(_ outcome: UpdateCheck.Outcome, current: AppVersion, download: (GitHubRelease) -> Void) {
        let alert = NSAlert()
        switch outcome {
        case .available(let release):
            alert.messageText = "PACE Launcher \(release.version) is available"
            alert.informativeText = "You have \(current). Download opens the release page in your browser. Install the new version the same way as the first one."
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
        case .upToDate:
            alert.messageText = "PACE Launcher \(current) is up to date."
        case .noRelease:
            alert.messageText = "No release is published on GitHub yet."
        case .failed(let reason):
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t check for updates"
            alert.informativeText = reason
        }
        NSApp.activate()
        let response = alert.runModal()
        if case .available(let release) = outcome, response == .alertFirstButtonReturn {
            download(release)
            // The browser takes focus; deactivating now could give it to
            // the previous app instead and leave the page behind.
            return
        }
        // Hand focus back unless Settings or the welcome window is open.
        let windowOpen = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) && $0.styleMask.contains(.titled) }
        if !windowOpen { NSApp.deactivate() }
    }
}
