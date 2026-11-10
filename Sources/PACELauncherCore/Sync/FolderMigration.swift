import Foundation

/// Moves data between the local folder and iCloud Drive without ever
/// losing or overwriting a file. Every file is copied, its bytes are
/// verified, and only then is the original deleted, so a run that stops
/// halfway can simply be run again.
public enum FolderMigration {
    public struct Report: Sendable, Equatable {
        /// Relative paths now in the destination under their own name.
        public var moved: [String] = []
        /// Relative paths that clashed, mapped to the name they got.
        public var renamed: [String: String] = [:]
        /// iCloud placeholders left in the source (not downloaded yet).
        public var skipped: [String] = []

        public init() {}
    }

    /// Thrown when a move stops partway; `report` lists what already moved.
    public struct Interrupted: LocalizedError {
        public let report: Report
        public let underlying: any Error

        public var errorDescription: String? { underlying.localizedDescription }
    }

    /// True for a file a move renamed to keep both copies, like
    /// "<UUID> (from This Mac).md" for `fileExtension` "md".
    public static func isRenamedCopy(_ name: String, fileExtension: String) -> Bool {
        let suffix = ")." + fileExtension
        guard name.count > 36, name.hasSuffix(suffix), UUID(uuidString: String(name.prefix(36))) != nil else { return false }
        return name.dropFirst(36).hasPrefix(" (from ")
    }

    private static let partialPrefix = ".dot-migrating-"

    /// Moves `source` into `destination`. A folder moves its contents
    /// (recursively); a single file moves to the `destination` path.
    /// Never overwrites: a clash gets " (from <label>)" before the extension.
    public static func move(from source: URL, to destination: URL, label: String) throws -> Report {
        var report = Report()
        let fileManager = FileManager.default
        var isFolder: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isFolder) else { return report }

        do {
            if !isFolder.boolValue {
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try moveFile(source, to: destination, relative: source.lastPathComponent, label: label, report: &report)
                return report
            }

            for relative in try files(in: source) {
                let name = (relative as NSString).lastPathComponent
                if name == ".DS_Store" || name.hasPrefix(partialPrefix) { continue }
                if ICloudPlaceholder.originalName(of: name) != nil {
                    report.skipped.append(relative)
                    continue
                }
                let target = destination.appending(path: relative)
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try moveFile(source.appending(path: relative), to: target, relative: relative, label: label, report: &report)
            }
        } catch {
            throw Interrupted(report: report, underlying: error)
        }
        removeEmptyFolders(in: source)
        return report
    }

    // MARK: - Private

    /// Relative paths of every file and symlink below `folder`.
    private static func files(in folder: URL) throws -> [String] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return [] }
        let base = folder.standardizedFileURL.path
        var result: [String] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true, values.isSymbolicLink != true { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(base + "/") else { continue }
            result.append(String(path.dropFirst(base.count + 1)))
        }
        return result.sorted()
    }

    private static func moveFile(_ file: URL, to target: URL, relative: String, label: String, report: inout Report) throws {
        var candidate = target
        var attempt = 1
        while isOccupied(candidate) {
            if sameContent(file, candidate) {
                // Already there (an earlier run copied it): just drop the original.
                try FileManager.default.removeItem(at: file)
                record(relative, target: target, candidate: candidate, report: &report)
                return
            }
            candidate = clashName(for: target, label: label, attempt: attempt)
            attempt += 1
        }

        // Copy under a temporary name, verify, then rename into place, so a
        // half-written file never appears under its real name.
        let partial = candidate.deletingLastPathComponent().appending(path: partialPrefix + UUID().uuidString)
        try FileManager.default.copyItem(at: file, to: partial)
        guard sameContent(file, partial) else {
            try? FileManager.default.removeItem(at: partial)
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: candidate.path])
        }
        try FileManager.default.moveItem(at: partial, to: candidate)
        try FileManager.default.removeItem(at: file)
        record(relative, target: target, candidate: candidate, report: &report)
    }

    private static func record(_ relative: String, target: URL, candidate: URL, report: inout Report) {
        if candidate == target {
            report.moved.append(relative)
        } else {
            let folder = (relative as NSString).deletingLastPathComponent
            report.renamed[relative] = folder.isEmpty ? candidate.lastPathComponent : folder + "/" + candidate.lastPathComponent
        }
    }

    /// "a.md" -> "a (from This Mac).md", then "a (from This Mac 2).md", ...
    private static func clashName(for target: URL, label: String, attempt: Int) -> URL {
        let name = target.deletingPathExtension().lastPathComponent
        let suffix = attempt == 1 ? " (from \(label))" : " (from \(label) \(attempt))"
        let renamed = target.deletingLastPathComponent().appending(path: name + suffix)
        return target.pathExtension.isEmpty ? renamed : renamed.appendingPathExtension(target.pathExtension)
    }

    /// A name is taken by a file, a symlink, or an iCloud placeholder: a new
    /// file under an evicted item's name would replace it in iCloud.
    private static func isOccupied(_ url: URL) -> Bool {
        let placeholder = url.deletingLastPathComponent().appending(path: "." + url.lastPathComponent + ".icloud")
        return FileManager.default.fileExists(atPath: url.path) || isSymlink(url)
            || FileManager.default.fileExists(atPath: placeholder.path)
    }

    private static func isSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private static func sameContent(_ a: URL, _ b: URL) -> Bool {
        let fileManager = FileManager.default
        if isSymlink(a) || isSymlink(b) {
            guard let left = try? fileManager.destinationOfSymbolicLink(atPath: a.path),
                  let right = try? fileManager.destinationOfSymbolicLink(atPath: b.path)
            else { return false }
            return left == right
        }
        guard let left = try? Data(contentsOf: a, options: .mappedIfSafe),
              let right = try? Data(contentsOf: b, options: .mappedIfSafe)
        else { return false }
        return left == right
    }

    /// Removes folders below `root` that are now empty (deepest first).
    private static func removeEmptyFolders(in root: URL) {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return }
        var folders: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isDirectory == true, values?.isSymbolicLink != true { folders.append(url) }
        }
        for folder in folders.sorted(by: { $0.path.count > $1.path.count }) {
            if (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }
}
