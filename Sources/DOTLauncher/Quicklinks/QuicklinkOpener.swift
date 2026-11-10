import AppKit
import DOTLauncherCore

/// Opens a quicklink's URL with the app macOS picks for it. Only the
/// quicklink's name is logged, never the text or the URL.
enum QuicklinkOpener {
    @discardableResult
    static func open(_ link: Quicklink, query: String) -> Bool {
        guard let url = link.url(for: query) else {
            Log.app.notice("quicklink \(link.name, privacy: .public) has a URL that can't be built")
            return false
        }
        let opened = NSWorkspace.shared.open(url)
        Log.app.info("opened quicklink \(link.name, privacy: .public): \(opened)")
        return opened
    }
}
