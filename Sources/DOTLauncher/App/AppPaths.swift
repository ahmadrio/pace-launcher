import Foundation

/// Where DOT keeps its data.
///
/// - `localRoot`: always used for SQLite databases (never synced).
/// - `fileRoot`: snippets, notes, scripts and settings.json; it is the
///   iCloud folder only while "Store data in iCloud Drive" is on.
///
/// Both roots can be redirected for testing with the UserDefaults keys
/// `DOTDataRootOverride` and `DOTiCloudRootOverride`.
enum AppPaths {
    static let syncEnabledKey = "syncEnabled"
    private static let dataOverrideKey = "DOTDataRootOverride"
    private static let iCloudOverrideKey = "DOTiCloudRootOverride"

    static var localRoot: URL {
        let root = override(dataOverrideKey)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "DOT Launcher")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Not created here: nothing may touch iCloud Drive unless sync is on.
    static var iCloudRoot: URL {
        override(iCloudOverrideKey)
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Mobile Documents/com~apple~CloudDocs/DOT Launcher")
    }

    static var isICloudOverridden: Bool { override(iCloudOverrideKey) != nil }

    static var isUsingTestFolders: Bool {
        override(dataOverrideKey) != nil || override(iCloudOverrideKey) != nil
    }

    static var syncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledKey)
    }

    static var fileRoot: URL { syncEnabled ? iCloudRoot : localRoot }

    static var launcherDatabase: URL { localRoot.appending(path: "launcher.sqlite") }
    static var clipboardDatabase: URL { localRoot.appending(path: "clipboard.sqlite") }
    /// Image clips as PNG files (local only, never synced or backed up).
    static var clipboardImagesDirectory: URL { localRoot.appending(path: "Clipboard Images") }
    /// Saved AI chats (local only, never synced or backed up).
    static var chatDatabase: URL { localRoot.appending(path: "chat.sqlite") }
    /// One JSON file per snippet.
    static var snippetsDirectory: URL { fileRoot.appending(path: "Snippets") }
    /// One Markdown file per note.
    static var notesDirectory: URL { fileRoot.appending(path: "Notes") }
    /// The main script commands folder (extra folders live in UserDefaults).
    static var scriptsDirectory: URL { fileRoot.appending(path: "Scripts") }
    static var settingsFile: URL { fileRoot.appending(path: "settings.json") }

    private static func override(_ key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else { return nil }
        return URL(filePath: (path as NSString).expandingTildeInPath)
    }
}
