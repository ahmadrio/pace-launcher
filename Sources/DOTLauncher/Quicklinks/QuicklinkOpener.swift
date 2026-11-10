import AppKit
import DOTLauncherCore

/// Opens a quicklink's URL in its chosen browser, or the one macOS picks.
/// Only the quicklink's name is logged, never the text or the URL.
enum QuicklinkOpener {
    enum Outcome: Equatable {
        case opened
        /// The chosen browser is not installed here; the default opened it.
        case openedInDefault(missing: String)
        case failed
    }

    /// `onLateFallback` runs (on the main actor) when the chosen browser
    /// fails to launch after `.opened` was returned; the link has then been
    /// opened in the default browser.
    @discardableResult
    static func open(_ link: Quicklink, query: String,
                     onLateFallback: @escaping @MainActor @Sendable (String) -> Void = { _ in }) -> Outcome {
        guard let url = link.url(for: query) else {
            Log.app.notice("quicklink \(link.name, privacy: .public) has a URL that can't be built")
            return .failed
        }
        if let browser = link.browser {
            // A stale LaunchServices record can point at an app that is gone.
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser),
               FileManager.default.fileExists(atPath: app.path) {
                // Completes asynchronously (off the main actor). On failure,
                // open the default browser instead and say so.
                let log = Log.app
                let name = name(of: browser)
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    guard let error else { return }
                    log.error("opening a quicklink in \(browser, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in
                        NSWorkspace.shared.open(url)
                        onLateFallback(name)
                    }
                }
                Log.app.info("opened quicklink \(link.name, privacy: .public) in \(browser, privacy: .public)")
                return .opened
            }
            Log.app.notice("quicklink browser \(browser, privacy: .public) is not installed; using the default")
            return NSWorkspace.shared.open(url) ? .openedInDefault(missing: browser) : .failed
        }
        let opened = NSWorkspace.shared.open(url)
        Log.app.info("opened quicklink \(link.name, privacy: .public): \(opened)")
        return opened ? .opened : .failed
    }

    /// Apps that open https:// links here, by name (for the "Open with" picker).
    static func browsers() -> [(name: String, bundleID: String)] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .compactMap { url -> (String, String)? in
                // Two copies of one browser share an id: list it once.
                guard let id = Bundle(url: url)?.bundleIdentifier, seen.insert(id.lowercased()).inserted else { return nil }
                return (FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), id)
            }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    /// "Brave Browser"; a known name or the id's last part when the app is not installed.
    static func name(of bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return BrowserNames.displayName(for: bundleID) }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
