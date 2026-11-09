import Foundation
import Testing
@testable import DOTLauncherCore

struct MigratorTests {
    @Test func `applies each step once and records the version`() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        let steps = ["CREATE TABLE a (x)", "CREATE TABLE b (y)"]

        try Migrator.migrate(db, steps: steps)
        try Migrator.migrate(db, steps: steps)

        #expect(try db.userVersion() == 2)
        #expect(try db.query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").map { $0["name"] }
            == [.text("a"), .text("b")])
    }

    @Test func `runs only new steps on upgrade`() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try Migrator.migrate(db, steps: ["CREATE TABLE a (x)"])
        try Migrator.migrate(db, steps: ["CREATE TABLE a (x)", "CREATE TABLE b (y)"])
        #expect(try db.userVersion() == 2)
    }
}

struct UsageStoreTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func `counts uses and remembers the last one`() throws {
        let store = try UsageStore(database: SQLiteDatabase(path: ":memory:"))

        try store.recordUse(of: "app:com.apple.Safari", at: now.addingTimeInterval(-60))
        try store.recordUse(of: "app:com.apple.Safari", at: now)

        let usage = try #require(store.usage(for: "app:com.apple.Safari"))
        #expect(usage.count == 2)
        #expect(usage.lastUsed == now)
        #expect(store.usage(for: "app:unknown") == nil)
    }

    @Test func `frecency is zero for unused items and positive for used ones`() throws {
        let store = try UsageStore(database: SQLiteDatabase(path: ":memory:"))
        try store.recordUse(of: "a", at: now)

        #expect(store.frecency(for: "a", now: now) > 0)
        #expect(store.frecency(for: "b", now: now) == 0)
    }

    @Test func `persists across reopening the database file`() throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "usage-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        try UsageStore(database: SQLiteDatabase(path: path)).recordUse(of: "a", at: now)
        let reopened = try UsageStore(database: SQLiteDatabase(path: path))

        #expect(reopened.usage(for: "a")?.count == 1)
    }
}
