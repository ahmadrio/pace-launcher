import Foundation

public struct NoteSummary: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let preview: String
    public let modifiedAt: Date
}

/// Notes as plain Markdown files (`<UUID>.md`) in one folder, so they can
/// be opened in any editor and synced as a folder later.
public struct NoteStore: Sendable {
    private let directory: URL
    private let trashFile: @Sendable (URL) throws -> Void

    /// `trash` moves a file to the Trash; tests pass a recorder.
    public init(directory: URL, trash: @escaping @Sendable (URL) throws -> Void) {
        self.directory = directory
        self.trashFile = trash
    }

    /// Every readable note, newest first. Files that are not `<UUID>.md`
    /// or not UTF-8 (conflict copies, junk) are skipped.
    public func list() throws -> [NoteSummary] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .compactMap { name -> NoteSummary? in
                guard name.hasSuffix(".md"), let id = UUID(uuidString: String(name.dropLast(3))),
                      let body = read(id)
                else { return nil }
                let modified = (try? FileManager.default.attributesOfItem(atPath: url(for: id).path)[.modificationDate] as? Date) ?? .distantPast
                return NoteSummary(id: id, title: NoteTitle.title(for: body), preview: NoteTitle.preview(for: body), modifiedAt: modified)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func load(_ id: UUID) throws -> String {
        guard let body = read(id) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url(for: id).path])
        }
        return body
    }

    /// Writes the note; a blank body removes it instead (no empty notes).
    public func save(_ id: UUID, body: String) throws {
        let url = url(for: id)
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(body.utf8).write(to: url, options: .atomic)
    }

    public func trash(_ id: UUID) throws {
        let url = url(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try trashFile(url)
    }

    private func read(_ id: UUID) -> String? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// iCloud placeholders (`.<UUID>.md.icloud`) for items that are in
    /// iCloud but not downloaded to this Mac yet.
    public func placeholders() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { name in
                guard let original = ICloudPlaceholder.originalName(of: name), original.hasSuffix(".md") else { return false }
                return UUID(uuidString: String(original.dropLast(3))) != nil
            }
            .sorted()
            .map { directory.appending(path: $0) }
    }

    /// Gives notes that a sync move renamed ("<UUID> (from This Mac).md")
    /// a fresh id, so both copies show up. Returns how many were adopted.
    public func adoptRenamedCopies() throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        var adopted = 0
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path)
        where FolderMigration.isRenamedCopy(name, fileExtension: "md") {
            try FileManager.default.moveItem(at: directory.appending(path: name), to: url(for: UUID()))
            adopted += 1
        }
        return adopted
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).md")
    }
}
