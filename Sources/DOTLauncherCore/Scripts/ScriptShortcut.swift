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
        let sorted = scripts.sorted {
            $0.metadata.title.localizedCaseInsensitiveCompare($1.metadata.title) == .orderedAscending
        }
        var titleCounts: [String: Int] = [:]
        for script in scripts { titleCounts[script.metadata.title, default: 0] += 1 }

        var rows = sorted.map { script in
            let shared = titleCounts[script.metadata.title, default: 0] > 1
            return Row(
                id: .script(key(for: script, mainFolder: mainFolder)),
                title: script.metadata.title,
                detail: shared ? script.url.deletingLastPathComponent().lastPathComponent : nil,
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
