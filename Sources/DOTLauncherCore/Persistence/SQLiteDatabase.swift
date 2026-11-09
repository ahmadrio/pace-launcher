import Foundation
import SQLite3

public enum SQLValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
}

public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String

    public var description: String { "SQLite error \(code): \(message)" }
}

/// One result row, addressable by column name.
public struct SQLRow: Sendable {
    let values: [String: SQLValue]

    public subscript(column: String) -> SQLValue {
        values[column] ?? .null
    }

    public func int(_ column: String) -> Int64? {
        if case .integer(let v) = self[column] { v } else { nil }
    }

    public func double(_ column: String) -> Double? {
        switch self[column] {
        case .real(let v): v
        case .integer(let v): Double(v)
        default: nil
        }
    }

    public func string(_ column: String) -> String? {
        if case .text(let v) = self[column] { v } else { nil }
    }

    public func data(_ column: String) -> Data? {
        if case .blob(let v) = self[column] { v } else { nil }
    }
}

/// A thin, synchronous wrapper around a SQLite connection.
///
/// Not thread safe on purpose: each instance is owned by exactly one actor
/// (or one test), which serializes access to it.
public final class SQLiteDatabase {
    private var handle: OpaquePointer?

    /// SQLITE_TRANSIENT is a C macro cast that does not import into Swift.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(path, &handle, flags, nil)
        guard status == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(path)"
            sqlite3_close(handle)
            handle = nil
            throw SQLiteError(code: status, message: message)
        }
        sqlite3_busy_timeout(handle, 2_000)
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    public var lastInsertRowID: Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    public var changes: Int {
        Int(sqlite3_changes(handle))
    }

    /// Runs one or more statements that take no bindings and return no rows.
    public func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard status == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteError(code: status, message: message)
        }
    }

    /// Runs a single statement with bindings, discarding any rows.
    public func run(_ sql: String, _ bindings: [SQLValue] = []) throws {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        while try step(statement) {}
    }

    /// Runs a single statement with bindings and collects every row.
    public func query(_ sql: String, _ bindings: [SQLValue] = []) throws -> [SQLRow] {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }

        let columnCount = sqlite3_column_count(statement)
        let names = (0..<columnCount).map { String(cString: sqlite3_column_name(statement, $0)) }

        var rows: [SQLRow] = []
        while try step(statement) {
            var values: [String: SQLValue] = [:]
            for index in 0..<columnCount {
                values[names[Int(index)]] = column(statement, index)
            }
            rows.append(SQLRow(values: values))
        }
        return rows
    }

    /// Runs `body` inside a transaction, rolling back if it throws.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func userVersion() throws -> Int {
        Int(try query("PRAGMA user_version").first?.int("user_version") ?? 0)
    }

    public func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    // MARK: - Private

    private func prepare(_ sql: String, _ bindings: [SQLValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK else { throw lastError(status) }

        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32 = switch value {
            case .null:
                sqlite3_bind_null(statement, index)
            case .integer(let v):
                sqlite3_bind_int64(statement, index, v)
            case .real(let v):
                sqlite3_bind_double(statement, index, v)
            case .text(let v):
                sqlite3_bind_text(statement, index, v, -1, Self.transient)
            case .blob(let v):
                v.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), Self.transient)
                }
            }
            guard result == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw lastError(result)
            }
        }
        return statement
    }

    /// Returns true while there is a row to read.
    private func step(_ statement: OpaquePointer?) throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        case let status: throw lastError(status)
        }
    }

    private func column(_ statement: OpaquePointer?, _ index: Int32) -> SQLValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            return .text(String(cString: sqlite3_column_text(statement, index)))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
            return .blob(Data(bytes: bytes, count: count))
        default:
            return .null
        }
    }

    private func lastError(_ status: Int32) -> SQLiteError {
        SQLiteError(code: status, message: String(cString: sqlite3_errmsg(handle)))
    }
}
