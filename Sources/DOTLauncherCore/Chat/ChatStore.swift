import Foundation

public enum ChatRole: String, Sendable { case user, assistant }

/// One stored chat message. `original` is the English text the model saw
/// or wrote when the message went through the translation bridge.
public struct SavedChatMessage: Sendable, Equatable {
    public let role: ChatRole
    public let text: String
    public let original: String?

    public init(role: ChatRole, text: String, original: String? = nil) {
        self.role = role
        self.text = text
        self.original = original
    }

    /// What the model saw, for rebuilding its transcript.
    public var modelText: String { original ?? text }

    /// The question and answer of a finished exchange; nil when the answer
    /// is blank (nothing worth keeping).
    public static func exchange(question: String, questionEnglish: String?, answer: String, answerEnglish: String?) -> [SavedChatMessage]? {
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return [
            SavedChatMessage(role: .user, text: question, original: questionEnglish),
            SavedChatMessage(role: .assistant, text: answer, original: answerEnglish),
        ]
    }
}

public struct ChatSummary: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let messageCount: Int
    public let updatedAt: Date

    public init(id: UUID, title: String, messageCount: Int, updatedAt: Date) {
        self.id = id
        self.title = title
        self.messageCount = messageCount
        self.updatedAt = updatedAt
    }
}

/// Saved AI chats in SQLite (local only, never synced).
public actor ChatStore {
    private static let migrations = [
        """
        CREATE TABLE chats (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX chats_order ON chats (updated_at DESC);
        CREATE TABLE chat_messages (
            chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            original TEXT,
            PRIMARY KEY (chat_id, position)
        );
        """,
    ]

    private let db: SQLiteDatabase
    /// Chats deleted while the app runs. An answer that was still streaming
    /// when its chat was deleted must not bring the chat back.
    private var deleted: Set<String> = []

    public init(path: String) throws {
        let db = try SQLiteDatabase(path: path)
        // secure_delete = ON (not macOS's default FAST): deleted text is
        // zeroed on every page, overflow pages included.
        try db.execute("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA secure_delete = ON;")
        try Migrator.migrate(db, steps: Self.migrations)
        self.db = db
    }

    /// Adds messages to chat `id`, creating it (titled after its first
    /// question) when it is new. The chat moves to the top of the list.
    public func append(_ messages: [SavedChatMessage], to id: UUID, at date: Date) throws {
        guard !messages.isEmpty, !deleted.contains(id.uuidString) else { return }
        let key = SQLValue.text(id.uuidString)
        let time = SQLValue.real(date.timeIntervalSince1970)
        try db.transaction {
            let exists = try !db.query("SELECT 1 AS one FROM chats WHERE id = ?", [key]).isEmpty
            if exists {
                try db.run("UPDATE chats SET updated_at = ? WHERE id = ?", [time, key])
            } else {
                let question = messages.first { $0.role == .user }?.text ?? ""
                try db.run(
                    "INSERT INTO chats (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)",
                    [key, .text(ChatTitle.title(for: question)), time, time]
                )
            }
            var position = try db.query("SELECT COALESCE(MAX(position), -1) AS last FROM chat_messages WHERE chat_id = ?", [key])
                .first?.int("last") ?? -1
            for message in messages {
                position += 1
                try db.run(
                    "INSERT INTO chat_messages (chat_id, position, role, text, original) VALUES (?, ?, ?, ?, ?)",
                    [key, .integer(position), .text(message.role.rawValue), .text(message.text),
                     message.original.map(SQLValue.text) ?? .null]
                )
            }
        }
    }

    /// Chats, most recently updated first. A query matches the title or
    /// any message (case-insensitive substring).
    public func chats(matching query: String = "", limit: Int = 10_000) throws -> [ChatSummary] {
        let query = query.trimmingCharacters(in: .whitespaces)
        var sql = """
            SELECT c.id, c.title, c.updated_at,
                   (SELECT COUNT(*) FROM chat_messages m WHERE m.chat_id = c.id) AS message_count
            FROM chats c
            """
        var bindings: [SQLValue] = []
        if !query.isEmpty {
            let escaped = query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
            let pattern = SQLValue.text("%" + escaped + "%")
            sql += """
                 WHERE c.title LIKE ? ESCAPE '\\'
                    OR EXISTS (SELECT 1 FROM chat_messages m WHERE m.chat_id = c.id AND m.text LIKE ? ESCAPE '\\')
                """
            bindings = [pattern, pattern]
        }
        sql += " ORDER BY c.updated_at DESC, c.rowid DESC LIMIT ?"
        bindings.append(.integer(Int64(limit)))

        return try db.query(sql, bindings).compactMap { row in
            guard let id = row.string("id").flatMap(UUID.init(uuidString:)),
                  let title = row.string("title"),
                  let updated = row.double("updated_at")
            else { return nil }
            return ChatSummary(
                id: id, title: title,
                messageCount: Int(row.int("message_count") ?? 0),
                updatedAt: Date(timeIntervalSince1970: updated)
            )
        }
    }

    public func messages(of id: UUID) throws -> [SavedChatMessage] {
        try db.query(
            "SELECT role, text, original FROM chat_messages WHERE chat_id = ? ORDER BY position",
            [.text(id.uuidString)]
        ).compactMap { row in
            guard let role = row.string("role").flatMap(ChatRole.init(rawValue:)), let text = row.string("text") else { return nil }
            return SavedChatMessage(role: role, text: text, original: row.string("original"))
        }
    }

    public func delete(_ id: UUID) throws {
        deleted.insert(id.uuidString)
        try db.run("DELETE FROM chats WHERE id = ?", [.text(id.uuidString)])
        flushDeletes()
    }

    public func deleteAll() throws {
        for row in try db.query("SELECT id FROM chats") {
            if let id = row.string("id") { deleted.insert(id) }
        }
        try db.run("DELETE FROM chats")
        flushDeletes()
    }

    /// Writes the WAL back and empties it, so deleted text does not linger
    /// there while the connection stays open.
    private func flushDeletes() {
        try? db.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }
}
