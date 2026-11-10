import Foundation

/// Global shortcuts for script commands: how a script is named in
/// settings.json, what a press does, and the rows Settings lists.
public enum ScriptShortcut {
    /// The path relative to `mainFolder` for scripts inside it (stable when
    /// sync moves the folder), else the full path.
    public static func key(for script: ScriptCommand, mainFolder: URL) -> String {
        let folder = mainFolder.standardizedFileURL.path + "/"
        let path = script.url.path
        return path.hasPrefix(folder) ? String(path.dropFirst(folder.count)) : path
    }

    public static func script(forKey key: String, in scripts: [ScriptCommand], mainFolder: URL) -> ScriptCommand? {
        scripts.first { self.key(for: $0, mainFolder: mainFolder) == key }
    }

    /// key → title of every found script, to tell whether shortcuts need re-applying.
    public static func fingerprint(of scripts: [ScriptCommand], mainFolder: URL) -> [String: String] {
        Dictionary(scripts.map { (key(for: $0, mainFolder: mainFolder), $0.metadata.title) }) { first, _ in first }
    }

    /// After a script reload: re-apply shortcuts when the scripts' keys or
    /// titles changed, or when a shortcut could not be registered (macOS may
    /// have freed its combo since, e.g. Spotlight's ⌘Space turned off).
    public static func shouldReapply(previous: [String: String], current: [String: String], anyUnavailable: Bool) -> Bool {
        previous != current || anyUnavailable
    }

    /// Where a script lives, for telling same-titled scripts apart:
    /// "Scripts", "Scripts/sub", or "~/bin" for an extra folder.
    static func folderLabel(for script: ScriptCommand, mainFolder: URL) -> String {
        let key = key(for: script, mainFolder: mainFolder)
        let folder = (key as NSString).deletingLastPathComponent
        if key.hasPrefix("/") { return (folder as NSString).abbreviatingWithTildeInPath }
        let name = mainFolder.standardizedFileURL.lastPathComponent
        return folder.isEmpty ? name : name + "/" + folder
    }

    public enum Step: Equatable, Sendable { case notExecutable, fillArguments, confirm, runInPanel, runInBackground }

    /// The launcher's order: executable → arguments → confirmation → mode.
    /// `isConfirmed` is evaluated only for a needsConfirmation script
    /// without arguments.
    public static func step(for script: ScriptCommand, isConfirmed: @autoclosure () -> Bool) -> Step {
        guard script.isExecutable else { return .notExecutable }
        guard script.metadata.arguments.isEmpty else { return .fillArguments }
        if script.metadata.needsConfirmation, !isConfirmed() { return .confirm }
        return script.metadata.mode == .fullOutput ? .runInPanel : .runInBackground
    }

    public struct Row: Equatable, Sendable {
        /// `.script(key)`.
        public let id: ShortcutID
        /// The script's title; the file name when it is missing.
        public let title: String
        /// The folder name when two scripts share a title; "Not found on
        /// this Mac" when missing.
        public let detail: String?
        public let isMissing: Bool

        public init(id: ShortcutID, title: String, detail: String?, isMissing: Bool) {
            self.id = id
            self.title = title
            self.detail = detail
            self.isMissing = isMissing
        }
    }

    /// Found scripts sorted by title (case-insensitive), then saved script
    /// shortcuts with no script, sorted by key.
    public static func rows(scripts: [ScriptCommand], mainFolder: URL, saved: [String: String]) -> [Row] {
        // Same titles keep a fixed order (by key) from launch to launch.
        let sorted = scripts.sorted {
            switch $0.metadata.title.localizedCaseInsensitiveCompare($1.metadata.title) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: key(for: $0, mainFolder: mainFolder) < key(for: $1, mainFolder: mainFolder)
            }
        }
        var titleCounts: [String: Int] = [:]
        for script in scripts { titleCounts[script.metadata.title, default: 0] += 1 }

        var rows = sorted.map { script in
            let shared = titleCounts[script.metadata.title, default: 0] > 1
            return Row(
                id: .script(key(for: script, mainFolder: mainFolder)),
                title: script.metadata.title,
                detail: shared ? folderLabel(for: script, mainFolder: mainFolder) : nil,
                isMissing: false
            )
        }
        let found = Set(rows.map(\.id))
        let missing = Shortcuts.resolve(saved).keys
            .filter { $0.group == .scripts && !found.contains($0) }
            .sorted { $0.rawValue < $1.rawValue }
        rows += missing.map { Row(id: $0, title: $0.title, detail: "Not found on this Mac", isMissing: true) }
        return rows
    }
}
