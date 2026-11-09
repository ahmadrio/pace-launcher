import Foundation

/// One JSON file per snippet (`<UUID>.json`), so a synced folder can merge
/// edits per snippet instead of conflicting on one database file.
public struct SnippetStore: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Every readable snippet, sorted by name. Files that are not
    /// `<UUID>.json` or do not decode (conflict copies, junk) are skipped.
    public func all() throws -> [Snippet] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { name in
                name.hasSuffix(".json") && UUID(uuidString: String(name.dropLast(5))) != nil
            }
            .compactMap { name in
                guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
                return try? decoder.decode(Snippet.self, from: data)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ snippet: Snippet) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snippet).write(to: url(for: snippet.id), options: .atomic)
    }

    public func delete(id: UUID) throws {
        let url = url(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// iCloud placeholders (`.<UUID>.json.icloud`) for items that are in
    /// iCloud but not downloaded to this Mac yet.
    public func placeholders() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { name in
                guard let original = ICloudPlaceholder.originalName(of: name), original.hasSuffix(".json") else { return false }
                return UUID(uuidString: String(original.dropLast(5))) != nil
            }
            .sorted()
            .map { directory.appending(path: $0) }
    }

    /// Gives snippets that a sync move renamed ("<UUID> (from This Mac).json")
    /// a fresh id, so both copies show up. Returns how many were adopted.
    /// Files that do not decode are left alone.
    public func adoptRenamedCopies() throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var adopted = 0
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path)
        where FolderMigration.isRenamedCopy(name, fileExtension: "json") {
            let file = directory.appending(path: name)
            guard let data = try? Data(contentsOf: file), var snippet = try? decoder.decode(Snippet.self, from: data) else { continue }
            snippet.id = UUID()
            try save(snippet)
            try FileManager.default.removeItem(at: file)
            adopted += 1
        }
        return adopted
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
