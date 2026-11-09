import Foundation
import Testing
@testable import DOTLauncherCore

struct SQLiteDatabaseTests {
    let db: SQLiteDatabase

    init() throws {
        db = try SQLiteDatabase(path: ":memory:")
    }

    @Test func `round-trips every value type through bindings`() throws {
        try db.execute("CREATE TABLE t (a TEXT, b INTEGER, c REAL, d BLOB, e TEXT)")
        try db.run(
            "INSERT INTO t VALUES (?, ?, ?, ?, ?)",
            [.text("héllo wörld"), .integer(42), .real(1.5), .blob(Data([1, 2, 3])), .null]
        )

        let rows = try db.query("SELECT a, b, c, d, e FROM t")

        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row["a"] == .text("héllo wörld"))
        #expect(row["b"] == .integer(42))
        #expect(row["c"] == .real(1.5))
        #expect(row["d"] == .blob(Data([1, 2, 3])))
        #expect(row["e"] == .null)
    }

    @Test func `reports the last inserted row id`() throws {
        try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)")
        try db.run("INSERT INTO t (v) VALUES (?)", [.text("one")])
        try db.run("INSERT INTO t (v) VALUES (?)", [.text("two")])
        #expect(db.lastInsertRowID == 2)
    }

    @Test func `throws on invalid SQL`() {
        #expect(throws: SQLiteError.self) {
            try db.execute("THIS IS NOT SQL")
        }
    }

    @Test func `rolls back a transaction when the body throws`() throws {
        try db.execute("CREATE TABLE t (v TEXT)")
        struct Boom: Error {}

        #expect(throws: Boom.self) {
            try db.transaction {
                try db.run("INSERT INTO t VALUES (?)", [.text("lost")])
                throw Boom()
            }
        }

        #expect(try db.query("SELECT v FROM t").isEmpty)
    }

    @Test func `stores and reads user_version`() throws {
        #expect(try db.userVersion() == 0)
        try db.setUserVersion(3)
        #expect(try db.userVersion() == 3)
    }

    @Test func `FTS5 trigram tokenizer matches substrings`() throws {
        try db.execute("CREATE VIRTUAL TABLE f USING fts5(body, tokenize='trigram')")
        try db.run("INSERT INTO f (body) VALUES (?)", [.text("hello world")])

        let rows = try db.query("SELECT body FROM f WHERE f MATCH ?", [.text("\"llo wo\"")])

        #expect(rows.map { $0["body"] } == [.text("hello world")])
    }
}
