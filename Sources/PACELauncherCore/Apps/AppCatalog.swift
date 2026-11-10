import Foundation

public struct AppEntry: Sendable, Hashable {
    public let name: String
    public let bundleID: String?
    /// Path as found during the scan (may be a symlink, like Safari's).
    public let path: String
    /// Other names to match, such as CFBundleDisplayName.
    public let aliases: [String]

    public init(name: String, bundleID: String?, path: String, aliases: [String] = []) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.aliases = aliases
    }

    /// Stable id for usage tracking.
    public var usageID: String {
        "app:" + (bundleID ?? path)
    }
}

public enum AppCatalog {
    /// One entry per bundle id (or per path when there is none), preferring
    /// copies in /Applications, sorted by name.
    public static func deduplicated(_ entries: [AppEntry]) -> [AppEntry] {
        var best: [String: AppEntry] = [:]
        for entry in entries {
            let key = entry.bundleID ?? entry.path
            if let existing = best[key], rank(existing) <= rank(entry) { continue }
            best[key] = entry
        }
        return best.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Lower is better.
    private static func rank(_ entry: AppEntry) -> (Int, Int) {
        let folder = switch entry.path {
        case let path where path.hasPrefix("/Applications/"): 0
        case let path where path.hasPrefix("/System/Applications/"): 1
        case let path where path.hasPrefix("/System/"): 2
        default: 3
        }
        return (folder, entry.path.count)
    }
}
