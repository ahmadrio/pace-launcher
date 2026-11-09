import Foundation

/// How often and how recently each launcher item was used. Kept in memory
/// for fast ranking and written through to SQLite.
public final class UsageStore {
    public struct Usage: Sendable, Equatable {
        public let count: Int
        public let lastUsed: Date
    }

    private static let migrations = [
        """
        CREATE TABLE usage (
            id TEXT PRIMARY KEY,
            count INTEGER NOT NULL,
            last_used REAL NOT NULL
        )
        """,
    ]

    private let db: SQLiteDatabase
    private var cache: [String: Usage] = [:]

    public init(database: SQLiteDatabase) throws {
        db = database
        try db.execute("PRAGMA journal_mode = WAL")
        try Migrator.migrate(db, steps: Self.migrations)
        for row in try db.query("SELECT id, count, last_used FROM usage") {
            guard let id = row.string("id"), let count = row.int("count"), let lastUsed = row.double("last_used") else { continue }
            cache[id] = Usage(count: Int(count), lastUsed: Date(timeIntervalSince1970: lastUsed))
        }
    }

    public func usage(for id: String) -> Usage? {
        cache[id]
    }

    public func frecency(for id: String, now: Date = .now) -> Double {
        guard let usage = cache[id] else { return 0 }
        return Frecency.score(count: usage.count, lastUsed: usage.lastUsed, now: now)
    }

    public func recordUse(of id: String, at date: Date = .now) throws {
        let updated = Usage(count: (cache[id]?.count ?? 0) + 1, lastUsed: date)
        try db.run(
            """
            INSERT INTO usage (id, count, last_used) VALUES (?, 1, ?)
            ON CONFLICT(id) DO UPDATE SET count = count + 1, last_used = excluded.last_used
            """,
            [.text(id), .real(date.timeIntervalSince1970)]
        )
        cache[id] = updated
    }
}
