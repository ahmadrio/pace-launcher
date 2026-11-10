import Foundation

/// The app was called DOT Launcher before its public release as PACE
/// Launcher. On first launch its data folder and settings move over once;
/// nothing is ever overwritten.
public enum LegacyMigration {
    public static let oldBundleID = "com.pace.DOTLauncher"
    public static let oldFolderName = "DOT Launcher"
    /// Set in the new defaults once the old ones were copied.
    public static let doneKey = "migratedFromDOTLauncher"

    public enum FolderOutcome: Equatable, Sendable {
        case moved
        case nothingToMove
        /// Both exist: nothing is touched and the new folder is used.
        case bothExist
    }

    /// Moves (renames) the whole folder, so SQLite files and their WAL
    /// companions stay together.
    public static func moveFolder(from old: URL, to new: URL, fileManager: FileManager = .default) throws -> FolderOutcome {
        guard fileManager.fileExists(atPath: old.path) else { return .nothingToMove }
        guard !fileManager.fileExists(atPath: new.path) else { return .bothExist }
        try fileManager.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: old, to: new)
        return .moved
    }

    /// Old defaults for the new app: window frames under their new names,
    /// and none of the test hooks (data folder overrides, dry run).
    public static func defaults(from old: [String: Any]) -> [String: Any] {
        let renamed = ["DOTNotesWindow": "PACENotesWindow", "DOTSettingsWindow": "PACESettingsWindow"]
        let testHooks: Set<String> = ["DOTDataRootOverride", "DOTiCloudRootOverride", "DOTRatesURLOverride", "DOTSystemCommandDryRun"]
        var result: [String: Any] = [:]
        for (key, value) in old where !testHooks.contains(key) {
            var newKey = key
            for (from, to) in renamed where key.hasSuffix(from) {
                newKey = String(key.dropLast(from.count)) + to
            }
            result[newKey] = value
        }
        return result
    }
}
