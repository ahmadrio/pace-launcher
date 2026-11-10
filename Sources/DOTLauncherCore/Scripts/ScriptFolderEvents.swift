import Foundation

/// Which file-system changes can change the scripts DOT finds.
public enum ScriptFolderEvents {
    /// What to watch for `folders`: the folders themselves, existing or not.
    /// FSEvents reports a watched path being created, so a Scripts folder
    /// that arrives later is seen without watching its parent (for a missing
    /// extra folder that parent could be ~, with every file in it).
    public static func watchPaths(for folders: [String]) -> [String] {
        var result: [String] = []
        for folder in folders.map(normalized) where !folder.isEmpty && !result.contains(folder) {
            result.append(folder)
        }
        return result
    }

    /// True when a change at `path` can change the scripts found in
    /// `folders`: the folder itself, or inside it with no hidden component
    /// and at most `maxDepth + 1` components below the folder (the scanner
    /// skips hidden entries and goes `maxDepth` subfolders deep).
    public static func isRelevant(_ path: String, folders: [String], maxDepth: Int = 3) -> Bool {
        let path = normalized(path)
        for folder in folders.map(normalized) {
            if path == folder { return true }
            guard path.hasPrefix(folder + "/") else { continue }
            let components = path.dropFirst(folder.count + 1).split(separator: "/")
            if components.contains(where: { $0.hasPrefix(".") }) { continue }
            if components.count <= maxDepth + 1 { return true }
        }
        return false
    }

    private static func normalized(_ path: String) -> String {
        var path = path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
