import Foundation

/// Unlimited clipboard history in SQLite, searchable through an FTS5
/// trigram index (substring matches, case and diacritic insensitive).
public actor ClipboardStore {
    private static let migrations = [
        """
        CREATE TABLE clips (
            id INTEGER PRIMARY KEY,
            hash TEXT NOT NULL UNIQUE,
            kind TEXT NOT NULL,
            text TEXT NOT NULL,
            source TEXT,
            created_at REAL NOT NULL,
            last_used_at REAL NOT NULL,
            use_count INTEGER NOT NULL DEFAULT 1,
            pinned INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX clips_order ON clips (pinned DESC, last_used_at DESC);
        CREATE TABLE representations (
            clip_id INTEGER NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
            type TEXT NOT NULL,
            data BLOB NOT NULL,
            PRIMARY KEY (clip_id, type)
        );
        CREATE VIRTUAL TABLE clips_fts USING fts5(
            text, content='clips', content_rowid='id', tokenize='trigram remove_diacritics 1'
        );
        CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN
            INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text);
        END;
        CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN
            INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text);
        END;
        CREATE TRIGGER clips_au AFTER UPDATE OF text ON clips BEGIN
            INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text);
            INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text);
        END;
        """,
    ]

    private static let columns = "c.id, c.hash, c.kind, c.text, c.source, c.created_at, c.last_used_at, c.use_count, c.pinned"
    private static let order = "ORDER BY c.pinned DESC, c.last_used_at DESC, c.id DESC"

    private let db: SQLiteDatabase
    /// Where image clips keep `<hash>.png` and `<hash>-thumb.png`.
    public nonisolated let imagesDirectory: URL?

    public init(path: String, imagesDirectory: URL? = nil) throws {
        let db = try SQLiteDatabase(path: path)
        // secure_delete = ON (not macOS's default FAST): deleted text is
        // zeroed on every page, overflow pages included.
        try db.execute("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA secure_delete = ON;")
        try Migrator.migrate(db, steps: Self.migrations)
        self.db = db
        self.imagesDirectory = imagesDirectory
    }

    /// The full picture of an image clip; nil when missing (for example
    /// after restoring a backup, which holds only the database).
    public nonisolated func imageURL(for item: ClipItem) -> URL? {
        existingFile(for: item, suffix: ".png")
    }

    public nonisolated func thumbnailURL(for item: ClipItem) -> URL? {
        existingFile(for: item, suffix: "-thumb.png")
    }

    private nonisolated func existingFile(for item: ClipItem, suffix: String) -> URL? {
        guard item.kind == .image, let imagesDirectory else { return nil }
        let url = imagesDirectory.appending(path: item.hash + suffix)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Stores a new clip, or bumps the existing one with the same content.
    @discardableResult
    public func save(_ draft: ClipDraft) throws -> ClipItem {
        try db.transaction { try insertOrBump(draft) }
    }

    /// Stores many clips in one transaction.
    public func save(_ drafts: [ClipDraft]) throws {
        try db.transaction {
            for draft in drafts { _ = try insertOrBump(draft) }
        }
    }

    public func recent(limit: Int = 50, offset: Int = 0) throws -> [ClipItem] {
        try db.query(
            "SELECT \(Self.columns) FROM clips c \(Self.order) LIMIT ? OFFSET ?",
            [.integer(Int64(limit)), .integer(Int64(offset))]
        ).compactMap(Self.item)
    }

    /// Substring search. Queries of three or more characters use the
    /// trigram index; shorter ones fall back to LIKE.
    public func search(_ query: String, limit: Int = 50) throws -> [ClipItem] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return try recent(limit: limit) }

        if query.count >= 3 {
            let phrase = "\"" + query.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            return try db.query(
                """
                SELECT \(Self.columns) FROM clips_fts f JOIN clips c ON c.id = f.rowid
                WHERE clips_fts MATCH ? \(Self.order) LIMIT ?
                """,
                [.text(phrase), .integer(Int64(limit))]
            ).compactMap(Self.item)
        }

        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return try db.query(
            "SELECT \(Self.columns) FROM clips c WHERE c.text LIKE ? ESCAPE '\\' \(Self.order) LIMIT ?",
            [.text("%" + escaped + "%"), .integer(Int64(limit))]
        ).compactMap(Self.item)
    }

    public func representations(of id: Int64) throws -> [ClipRepresentation] {
        try db.query("SELECT type, data FROM representations WHERE clip_id = ?", [.integer(id)]).compactMap { row in
            guard let type = row.string("type"), let data = row.data("data") else { return nil }
            return ClipRepresentation(type: type, data: data)
        }
    }

    public func markUsed(_ id: Int64, at date: Date = .now) throws {
        try db.run(
            "UPDATE clips SET last_used_at = ?, use_count = use_count + 1 WHERE id = ?",
            [.real(date.timeIntervalSince1970), .integer(id)]
        )
    }

    /// Flips the pin in the database and returns the new state, so two
    /// quick presses always end where they started.
    @discardableResult
    public func togglePinned(_ id: Int64) throws -> Bool {
        try db.transaction {
            try db.run("UPDATE clips SET pinned = 1 - pinned WHERE id = ?", [.integer(id)])
            return try db.query("SELECT pinned FROM clips WHERE id = ?", [.integer(id)]).first?.int("pinned") == 1
        }
    }

    /// Deletes image files no clip refers to (left by a crash or by
    /// restoring a backup). Returns how many files were removed.
    @discardableResult
    public func removeOrphanImages() throws -> Int {
        guard let imagesDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)
        else { return 0 }
        let used = Set(try db.query("SELECT hash FROM clips WHERE kind = ?", [.text(ClipKind.image.rawValue)]).compactMap { $0.string("hash") })
        var removed = 0
        for name in names where name.hasSuffix(".png") {
            let hash = name.hasSuffix("-thumb.png") ? String(name.dropLast("-thumb.png".count)) : String(name.dropLast(".png".count))
            guard !used.contains(hash) else { continue }
            if (try? FileManager.default.removeItem(at: imagesDirectory.appending(path: name))) != nil { removed += 1 }
        }
        return removed
    }

    public func setPinned(_ id: Int64, _ pinned: Bool) throws {
        try db.run("UPDATE clips SET pinned = ? WHERE id = ?", [.integer(pinned ? 1 : 0), .integer(id)])
    }

    /// Removes unpinned clips last used before `cutoff`, with their image
    /// files. Returns how many were removed.
    @discardableResult
    public func prune(lastUsedBefore cutoff: Date) throws -> Int {
        try deleteUnpinned(where: "last_used_at < ?", [.real(cutoff.timeIntervalSince1970)])
    }

    /// Removes every unpinned clip (Clear History).
    @discardableResult
    public func clearUnpinned() throws -> Int {
        try deleteUnpinned(where: "1 = 1", [])
    }

    /// Removes what deleted clips leave behind: the search index keeps the
    /// trigrams of deleted text (with tombstones) until it is merged, and
    /// the WAL keeps old pages while the connection stays open.
    private func flushDeletes() {
        try? db.execute("INSERT INTO clips_fts (clips_fts) VALUES ('optimize');")
        try? db.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    private func deleteUnpinned(where condition: String, _ bindings: [SQLValue]) throws -> Int {
        let (count, images) = try db.transaction { () -> (Int, [String]) in
            let images = try db.query(
                "SELECT hash FROM clips WHERE pinned = 0 AND kind = 'image' AND \(condition)", bindings
            ).compactMap { $0.string("hash") }
            let count = try db.query("SELECT COUNT(*) AS n FROM clips WHERE pinned = 0 AND \(condition)", bindings)
                .first?.int("n") ?? 0
            try db.run("DELETE FROM clips WHERE pinned = 0 AND \(condition)", bindings)
            return (Int(count), images)
        }
        if count > 0 { flushDeletes() }
        if let imagesDirectory {
            for hash in images {
                for suffix in [".png", "-thumb.png"] {
                    try? FileManager.default.removeItem(at: imagesDirectory.appending(path: hash + suffix))
                }
            }
        }
        return count
    }

    public func delete(_ id: Int64) throws {
        let image = try db.query("SELECT hash FROM clips WHERE id = ? AND kind = ?", [.integer(id), .text(ClipKind.image.rawValue)])
            .first?.string("hash")
        try db.run("DELETE FROM clips WHERE id = ?", [.integer(id)])
        flushDeletes()
        if let image, let imagesDirectory {
            for suffix in [".png", "-thumb.png"] {
                try? FileManager.default.removeItem(at: imagesDirectory.appending(path: image + suffix))
            }
        }
    }

    /// Writes a consistent copy of the history to `path`.
    public func backup(to path: String) throws {
        try db.backup(to: path)
    }

    /// Replaces the history with a backup, then upgrades its schema if the
    /// backup came from an older version.
    public func restore(from path: String) throws {
        try db.restore(from: path)
        try Migrator.migrate(db, steps: Self.migrations)
    }

    public func count() throws -> Int {
        Int(try db.query("SELECT COUNT(*) AS n FROM clips").first?.int("n") ?? 0)
    }

    // MARK: - Private

    private func insertOrBump(_ draft: ClipDraft) throws -> ClipItem {
        let hash = draft.contentHash
        let time = draft.date.timeIntervalSince1970
        if let image = draft.image { try writeFiles(of: image, named: hash) }

        if let existing = try db.query("SELECT id FROM clips WHERE hash = ?", [.text(hash)]).first?.int("id") {
            try db.run(
                "UPDATE clips SET last_used_at = ?, use_count = use_count + 1, source = COALESCE(?, source) WHERE id = ?",
                [.real(time), draft.sourceBundleID.map(SQLValue.text) ?? .null, .integer(existing)]
            )
            return try item(id: existing)
        }

        try db.run(
            """
            INSERT INTO clips (hash, kind, text, source, created_at, last_used_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [.text(hash), .text(draft.kind.rawValue), .text(draft.text),
             draft.sourceBundleID.map(SQLValue.text) ?? .null, .real(time), .real(time)]
        )
        let id = db.lastInsertRowID
        for representation in draft.representations {
            try db.run(
                "INSERT OR REPLACE INTO representations (clip_id, type, data) VALUES (?, ?, ?)",
                [.integer(id), .text(representation.type), .blob(representation.data)]
            )
        }
        return try item(id: id)
    }

    /// Writes the picture and thumbnail unless they are already there.
    private func writeFiles(of image: ClipImage, named hash: String) throws {
        guard let imagesDirectory else { throw SQLiteError(code: 0, message: "no folder for image clips") }
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        for (suffix, data) in [(".png", image.png), ("-thumb.png", image.thumbnail)] {
            let url = imagesDirectory.appending(path: hash + suffix)
            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            }
        }
    }

    private func item(id: Int64) throws -> ClipItem {
        guard let item = try db.query("SELECT \(Self.columns) FROM clips c WHERE c.id = ?", [.integer(id)])
            .first.flatMap(Self.item)
        else {
            throw SQLiteError(code: 0, message: "clip \(id) vanished")
        }
        return item
    }

    private static func item(_ row: SQLRow) -> ClipItem? {
        guard let id = row.int("id"),
              let hash = row.string("hash"),
              let kind = row.string("kind").flatMap(ClipKind.init(rawValue:)),
              let text = row.string("text"),
              let created = row.double("created_at"),
              let lastUsed = row.double("last_used_at")
        else { return nil }
        return ClipItem(
            id: id,
            hash: hash,
            text: text,
            kind: kind,
            sourceBundleID: row.string("source"),
            createdAt: Date(timeIntervalSince1970: created),
            lastUsedAt: Date(timeIntervalSince1970: lastUsed),
            useCount: Int(row.int("use_count") ?? 1),
            pinned: row.int("pinned") == 1
        )
    }
}
