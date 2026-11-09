import Foundation
import Testing
@testable import DOTLauncherCore

/// A temporary folder, removed by `remove()`.
struct TemporaryFolder {
    let url = FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-\(UUID().uuidString)")

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }

    func write(_ name: String, _ text: String) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url.appending(path: name))
    }
}

struct SnippetStoreTests {
    @Test func `saves and lists snippets sorted by name`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = SnippetStore(directory: folder.url)

        try store.save(Snippet(name: "Signature", content: "Regards"))
        try store.save(Snippet(name: "Address", keyword: ";addr", content: "Jl. Contoh 1"))

        let all = try store.all()
        #expect(all.map(\.name) == ["Address", "Signature"])
        #expect(all.first?.keyword == ";addr")
    }

    @Test func `saving again updates in place`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = SnippetStore(directory: folder.url)
        var snippet = Snippet(name: "Greeting", content: "Hi")
        try store.save(snippet)

        snippet.content = "Hello"
        try store.save(snippet)

        #expect(folder.files() == ["\(snippet.id.uuidString).json"])
        #expect(try store.all().map(\.content) == ["Hello"])
    }

    @Test func `delete removes the file`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = SnippetStore(directory: folder.url)
        let snippet = Snippet(name: "Temp", content: "x")
        try store.save(snippet)

        try store.delete(id: snippet.id)

        #expect(try store.all().isEmpty)
        #expect(folder.files().isEmpty)
    }

    @Test func `skips foreign and corrupt files`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = SnippetStore(directory: folder.url)
        try store.save(Snippet(name: "Valid", content: "ok"))
        try folder.write(".DS_Store", "junk")
        try folder.write("notes.txt", "not a snippet")
        try folder.write("\(UUID().uuidString).json", "{")
        try folder.write("abc 2.json", #"{"name":"Conflict"}"#)

        #expect(try store.all().map(\.name) == ["Valid"])
    }

    @Test func `lists nothing when the folder does not exist yet`() throws {
        let folder = TemporaryFolder()
        #expect(try SnippetStore(directory: folder.url).all().isEmpty)
    }
}

struct SnippetExpanderTests {
    let now = ISO8601DateFormatter().date(from: "2026-11-09T14:05:00Z")!
    let utc = TimeZone(identifier: "UTC")!

    @Test func `expands placeholders`() {
        #expect(SnippetExpander.expand("Today {date} at {time}", now: now, clipboard: nil, timeZone: utc) == "Today 2026-11-09 at 14:05")
        #expect(SnippetExpander.expand("{datetime}", now: now, clipboard: nil, timeZone: utc) == "2026-11-09 14:05")
        #expect(SnippetExpander.expand("Paste: {clipboard}", now: now, clipboard: "hi", timeZone: utc) == "Paste: hi")
        #expect(SnippetExpander.expand("Paste: {clipboard}", now: now, clipboard: nil, timeZone: utc) == "Paste: ")
    }

    @Test func `keeps unknown placeholders`() {
        #expect(SnippetExpander.expand("{cursor} {date}", now: now, clipboard: nil, timeZone: utc) == "{cursor} 2026-11-09")
    }

    @Test func `an unclosed brace is left as written`() {
        #expect(SnippetExpander.expand("a {date} b {oops", now: now, clipboard: nil, timeZone: utc) == "a 2026-11-09 b {oops")
    }

    @Test func `clipboard text is inserted literally`() {
        for _ in 0..<20 {   // dictionary order varies between runs
            #expect(SnippetExpander.expand("[{clipboard}] {date}", now: now, clipboard: "{date}", timeZone: utc) == "[{date}] 2026-11-09")
        }
    }

    @Test func `uses the given time zone`() {
        let jakarta = TimeZone(identifier: "Asia/Jakarta")!
        #expect(SnippetExpander.expand("{time}", now: now, clipboard: nil, timeZone: jakarta) == "21:05")
    }
}
