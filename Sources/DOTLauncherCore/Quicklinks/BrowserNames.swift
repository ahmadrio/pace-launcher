/// Readable names for browser bundle ids, for messages about a browser
/// that is not installed (so there is no app to ask for its name).
public enum BrowserNames {
    /// A known browser's name, else the last part of the id ("coolbrowser").
    public static func displayName(for bundleID: String) -> String {
        if let name = known[bundleID.lowercased()] { return name }
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }

    private static let known: [String: String] = [
        "com.google.chrome": "Google Chrome", "com.google.chrome.canary": "Chrome Canary",
        "com.apple.safari": "Safari", "com.apple.safaritechnologypreview": "Safari Technology Preview",
        "com.brave.browser": "Brave Browser", "org.mozilla.firefox": "Firefox",
        "org.mozilla.firefoxdeveloperedition": "Firefox Developer Edition", "company.thebrowser.browser": "Arc",
        "com.microsoft.edgemac": "Microsoft Edge", "com.kagi.kagimacos": "Orion", "com.operasoftware.opera": "Opera",
        "com.vivaldi.vivaldi": "Vivaldi", "app.zen-browser.zen": "Zen", "org.chromium.chromium": "Chromium",
    ]
}
