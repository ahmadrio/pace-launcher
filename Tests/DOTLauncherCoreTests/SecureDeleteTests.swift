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

struct SecureDeleteTests {
    @Test func `deleted chat text does not stay in the database file`() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-chat-\(UUID().uuidString).sqlite").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        let id = UUID()
        do {
            let store = try ChatStore(path: path)
            try await store.append([
                // Long enough for overflow pages, which a FAST secure_delete leaves alone.
                SavedChatMessage(role: .user, text: String(repeating: "zebra-marker-123 question ", count: 800)),
                SavedChatMessage(role: .assistant, text: String(repeating: "zebra-marker-123 answer ", count: 800)),
            ], to: id, at: .now)
            try await store.delete(id)
        }
        #expect(!fileContains("zebra-marker-123", database: path))
    }

    @Test func `deleted clip text does not stay in the database file`() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-clips-\(UUID().uuidString).sqlite").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        do {
            let store = try ClipboardStore(path: path)
            let secret = String(repeating: "okapi-marker-456 secret ", count: 800)
            let item = try await store.save(ClipDraft(text: secret, kind: .text, representations: [
                ClipRepresentation(type: "public.utf8-plain-text", data: Data(secret.utf8)),
            ], sourceBundleID: nil, date: .now))
            try await store.delete(item.id)
        }
        #expect(!fileContains("okapi-marker-456", database: path))
    }
}
