import Foundation
import PACELauncherCore

/// Where PACE keeps its data.
///
/// - `localRoot`: always used for SQLite databases (never synced).
/// - `fileRoot`: snippets, notes, scripts and settings.json; it is the
///   iCloud folder only while "Store data in iCloud Drive" is on.
///
/// Both roots can be redirected for testing with the UserDefaults keys
/// `PACEDataRootOverride` and `PACEiCloudRootOverride`.
enum AppPaths {
    static let syncEnabledKey = "syncEnabled"
    static let folderName = "PACE Launcher"
    private static let dataOverrideKey = "PACEDataRootOverride"
    private static let iCloudOverrideKey = "PACEiCloudRootOverride"

    static var localRoot: URL {
        let root = override(dataOverrideKey)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: folderName)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Not created here: nothing may touch iCloud Drive unless sync is on.
    static var iCloudRoot: URL {
        override(iCloudOverrideKey)
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Mobile Documents/com~apple~CloudDocs").appending(path: folderName)
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
    /// Cached exchange rates (local only).
    static var exchangeRatesFile: URL { localRoot.appending(path: "exchange-rates.json") }
    /// Saved AI chats (local only, never synced or backed up).
    static var chatDatabase: URL { localRoot.appending(path: "chat.sqlite") }
    /// One JSON file per snippet.
    static var snippetsDirectory: URL { fileRoot.appending(path: "Snippets") }
    /// One Markdown file per note.
    static var notesDirectory: URL { fileRoot.appending(path: "Notes") }
    /// The main script commands folder (extra folders live in UserDefaults).
    static var scriptsDirectory: URL { fileRoot.appending(path: "Scripts") }
    static var settingsFile: URL { fileRoot.appending(path: "settings.json") }

    /// The app was called DOT Launcher before: its settings and data move
    /// over once, before anything reads a path. Nothing is overwritten, and
    /// iCloud Drive is only touched while sync is on. Skipped with test
    /// folders.
    static func migrateLegacyData() {
        guard !isUsingTestFolders else { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: LegacyMigration.doneKey) {
            if let old = defaults.persistentDomain(forName: LegacyMigration.oldBundleID) {
                for (key, value) in LegacyMigration.defaults(from: old) where defaults.object(forKey: key) == nil {
                    defaults.set(value, forKey: key)
                }
                Log.app.notice("copied DOT Launcher's settings")
            }
            defaults.set(true, forKey: LegacyMigration.doneKey)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        moveLegacyFolder(support.appending(path: LegacyMigration.oldFolderName), to: support.appending(path: folderName), what: "data")
        if syncEnabled {
            let drive = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Mobile Documents/com~apple~CloudDocs")
            moveLegacyFolder(drive.appending(path: LegacyMigration.oldFolderName), to: drive.appending(path: folderName), what: "iCloud data")
        }
    }

    private static func moveLegacyFolder(_ old: URL, to new: URL, what: String) {
        do {
            switch try LegacyMigration.moveFolder(from: old, to: new) {
            case .moved: Log.app.notice("moved DOT Launcher's \(what, privacy: .public) to PACE Launcher")
            case .bothExist: Log.app.notice("DOT Launcher's \(what, privacy: .public) left in place: PACE Launcher's already exists")
            case .nothingToMove: break
            }
        } catch {
            Log.app.error("could not move DOT Launcher's \(what, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func override(_ key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else { return nil }
        return URL(filePath: (path as NSString).expandingTildeInPath)
    }
}
