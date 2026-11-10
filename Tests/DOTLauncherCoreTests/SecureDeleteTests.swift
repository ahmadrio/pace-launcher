import Foundation
import Testing
@testable import DOTLauncherCore

/// True when `marker` appears in the database file or its WAL.
private func fileContains(_ marker: String, database path: String) -> Bool {
    let needle = Data(marker.utf8)
    for file in [path, path + "-wal"] {
        if let data = FileManager.default.contents(atPath: file), data.range(of: needle) != nil { return true }
    }
    return false
}

private func temporaryDatabase(_ name: String) -> String {
    FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-\(name)-\(UUID().uuidString).sqlite").path
}

private func removeDatabase(_ path: String) {
    for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) }
}

/// Segment pages of the full-text index (rows 1 and 10 are FTS5's own
/// averages and structure records; segments hold the trigrams).
private func indexSegments(_ path: String) throws -> Int64 {
    let db = try SQLiteDatabase(path: path, readOnly: true)
    return try db.query("SELECT COUNT(*) AS n FROM clips_fts_data WHERE id > 10").first?.int("n") ?? 0
}

struct SecureDeleteTests {
    // Long texts: macOS's default FAST secure_delete leaves overflow pages alone.
    @Test func `deleted chat text does not stay in the database file`() async throws {
        let path = temporaryDatabase("chat")
        defer { removeDatabase(path) }
        let store = try ChatStore(path: path)
        let id = UUID()
        try await store.append([
            SavedChatMessage(role: .user, text: String(repeating: "zebra-marker-123 question ", count: 800)),
            SavedChatMessage(role: .assistant, text: String(repeating: "zebra-marker-123 answer ", count: 800)),
        ], to: id, at: .now)
        try await store.delete(id)

        // The app keeps its connection open, so check before closing.
        #expect(!fileContains("zebra-marker-123", database: path))
        withExtendedLifetime(store) {}
    }

    @Test func `deleted clip text does not stay in the database file`() async throws {
        let path = temporaryDatabase("clips")
        defer { removeDatabase(path) }
        let store = try ClipboardStore(path: path)
        let secret = String(repeating: "okapi-marker-456 secret ", count: 800)
        let item = try await store.save(ClipDraft(text: secret, kind: .text, representations: [
            ClipRepresentation(type: "public.utf8-plain-text", data: Data(secret.utf8)),
        ], sourceBundleID: nil, date: .now))
        try await store.delete(item.id)

        #expect(!fileContains("okapi-marker-456", database: path))
        withExtendedLifetime(store) {}
    }

    @Test func `deleting clips leaves no search index behind`() async throws {
        let path = temporaryDatabase("fts")
        defer { removeDatabase(path) }
        let store = try ClipboardStore(path: path)
        let a = try await store.save(ClipDraft(text: "wombat quokka numbat secret one", kind: .text, representations: [], sourceBundleID: nil, date: .now))
        try await store.save(ClipDraft(text: "platypus echidna secret two", kind: .text, representations: [], sourceBundleID: nil, date: .now))

        try await store.delete(a.id)
        try await store.clearUnpinned()

        // Deleted rows leave tombstones next to the original trigrams
        // until the index is merged.
        #expect(try indexSegments(path) == 0)
        withExtendedLifetime(store) {}
    }
}
