import Foundation
import Synchronization
import Testing
@testable import PACELauncherCore

struct NoteTitleTests {
    @Test(arguments: [
        ("\n\n## Groceries\nmilk", "Groceries"),
        ("   ", "Untitled"),
        ("Plain", "Plain"),
        ("#Tight heading", "Tight heading"),
    ])
    func `title comes from the first non-empty line without heading marks`(body: String, title: String) {
        #expect(NoteTitle.title(for: body) == title)
    }

    @Test func `preview is the next non-empty line`() {
        #expect(NoteTitle.preview(for: "# Groceries\n\n- milk\n- eggs") == "- milk")
        #expect(NoteTitle.preview(for: "Only a title") == "")
        #expect(NoteTitle.preview(for: "T\n" + String(repeating: "x", count: 200)).count == 80)
    }
}

/// Records what the store asked to trash (and removes it, like the Trash would).
final class TrashRecorder: Sendable {
    let urls = Mutex<[URL]>([])
}

struct NoteStoreTests {
    private func makeStore(_ folder: TemporaryFolder, trashed: TrashRecorder? = nil) -> NoteStore {
        NoteStore(directory: folder.url) { url in
            trashed?.urls.withLock { $0.append(url) }
            try FileManager.default.removeItem(at: url)
        }
    }

    @Test func `save then load round-trips`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = makeStore(folder)
        let id = UUID()

        try store.save(id, body: "# Hello\nWorld ✨")

        #expect(try store.load(id) == "# Hello\nWorld ✨")
        #expect(folder.files() == ["\(id.uuidString).md"])
    }

    @Test func `list is newest first`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = makeStore(folder)
        let a = UUID(), b = UUID()
        try store.save(a, body: "A")
        try store.save(b, body: "B")
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now.addingTimeInterval(60)],
            ofItemAtPath: folder.url.appending(path: "\(a.uuidString).md").path
        )

        let list = try store.list()

        #expect(list.map(\.id) == [a, b])
        #expect(list.map(\.title) == ["A", "B"])
    }

    @Test func `saving an empty body removes the note`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = makeStore(folder)
        let id = UUID()
        try store.save(id, body: "draft")

        try store.save(id, body: "  \n ")

        #expect(try store.list().isEmpty)
        #expect(folder.files().isEmpty)
    }

    @Test func `trash hands the file to the trash function`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let trashed = TrashRecorder()
        let store = makeStore(folder, trashed: trashed)
        let id = UUID()
        try store.save(id, body: "to trash")

        try store.trash(id)

        #expect(trashed.urls.withLock { $0.map(\.lastPathComponent) } == ["\(id.uuidString).md"])
        #expect(try store.list().isEmpty)
    }

    @Test func `skips foreign files`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = makeStore(folder)
        try store.save(UUID(), body: "Valid note")
        try folder.write(".DS_Store", "junk")
        try folder.write("x.txt", "not a note")
        try folder.write("abc 2.md", "conflict copy")
        try Data([0xFF, 0xFE, 0x00]).write(to: folder.url.appending(path: "\(UUID().uuidString).md"))

        #expect(try store.list().map(\.title) == ["Valid note"])
    }

    @Test func `lists nothing when the folder does not exist yet`() throws {
        #expect(try makeStore(TemporaryFolder()).list().isEmpty)
    }
}
