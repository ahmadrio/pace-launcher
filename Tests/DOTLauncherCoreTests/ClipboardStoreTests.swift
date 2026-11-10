import Foundation
import Testing
@testable import DOTLauncherCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func draft(_ text: String, kind: ClipKind = .text, at date: Date = t0, source: String? = "com.apple.Safari") -> ClipDraft {
    ClipDraft(
        text: text,
        kind: kind,
        representations: [ClipRepresentation(type: "public.utf8-plain-text", data: Data(text.utf8))],
        sourceBundleID: source,
        date: date
    )
}

struct ClipboardStoreTests {
    @Test func `saves a clip and lists it as recent`() async throws {
        let store = try ClipboardStore(path: ":memory:")

        try await store.save(draft("hello world"))
        let recent = try await store.recent()

        #expect(recent.map(\.text) == ["hello world"])
        #expect(recent.first?.sourceBundleID == "com.apple.Safari")
        #expect(recent.first?.useCount == 1)
    }

    @Test func `copying the same text again bumps it instead of adding a row`() async throws {
        let store = try ClipboardStore(path: ":memory:")

        try await store.save(draft("same", at: t0))
        try await store.save(draft("other", at: t0.addingTimeInterval(10)))
        try await store.save(draft("same", at: t0.addingTimeInterval(20)))

        let recent = try await store.recent()
        #expect(recent.map(\.text) == ["same", "other"])
        #expect(recent.first?.useCount == 2)
        #expect(try await store.count() == 2)
    }

    @Test func `keeps representations for pasting`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        let rich = ClipDraft(
            text: "bold",
            kind: .richText,
            representations: [
                ClipRepresentation(type: "public.rtf", data: Data("{\\rtf1 bold}".utf8)),
                ClipRepresentation(type: "public.utf8-plain-text", data: Data("bold".utf8)),
            ],
            sourceBundleID: nil,
            date: t0
        )

        let item = try await store.save(rich)
        let representations = try await store.representations(of: item.id)

        #expect(Set(representations.map(\.type)) == ["public.rtf", "public.utf8-plain-text"])
        #expect(item.kind == .richText)
    }

    @Test func `searches substrings with the trigram index`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        try await store.save(draft("hello world"))
        try await store.save(draft("goodbye"))

        #expect(try await store.search("llo wo").map(\.text) == ["hello world"])
        #expect(try await store.search("HELLO").map(\.text) == ["hello world"])
    }

    @Test func `short queries fall back to LIKE`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        try await store.save(draft("ab12"))
        try await store.save(draft("zz"))

        #expect(try await store.search("b1").map(\.text) == ["ab12"])
    }

    @Test func `LIKE wildcards in the query are literal`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        try await store.save(draft("100%"))
        try await store.save(draft("1000"))

        #expect(try await store.search("0%").map(\.text) == ["100%"])
    }

    @Test func `deleting a clip removes it from search`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        let item = try await store.save(draft("secret-ish note"))

        try await store.delete(item.id)

        #expect(try await store.search("secret").isEmpty)
        #expect(try await store.representations(of: item.id).isEmpty)
    }

    @Test func `pinned clips come first`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        let old = try await store.save(draft("old", at: t0))
        try await store.save(draft("new", at: t0.addingTimeInterval(60)))

        try await store.setPinned(old.id, true)

        #expect(try await store.recent().map(\.text) == ["old", "new"])
    }

    @Test func `marking a clip used moves it to the top`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        let first = try await store.save(draft("first", at: t0))
        try await store.save(draft("second", at: t0.addingTimeInterval(10)))

        try await store.markUsed(first.id, at: t0.addingTimeInterval(20))

        #expect(try await store.recent().map(\.text) == ["first", "second"])
    }

    @Test func `search stays fast with ten thousand clips`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        let drafts = (0..<10_000).map { draft("clip number \($0) lorem ipsum dolor", at: t0.addingTimeInterval(Double($0))) }
        try await store.save(drafts)

        let started = ContinuousClock.now
        let results = try await store.search("number 9999")
        let elapsed = started.duration(to: .now)

        #expect(results.map(\.text) == ["clip number 9999 lorem ipsum dolor"])
        #expect(elapsed < .milliseconds(50))
    }
}

struct ClipboardFilterTests {
    @Test func `an image with no text is kept`() {
        #expect(!ClipboardFilter.shouldIgnore(types: ["public.png"], text: nil, hasFiles: false, hasImage: true))
    }

    @Test func `a secret marker still wins over an image`() {
        #expect(ClipboardFilter.shouldIgnore(types: ["public.png", "org.nspasteboard.ConcealedType"], text: nil, hasFiles: false, hasImage: true))
    }

    @Test func `a copy with text and an image is not an image clip`() {
        #expect(!ClipboardFilter.isImageCopy(types: ["public.utf8-plain-text", "public.png"], text: "A1", hasFiles: false))
        #expect(ClipboardFilter.isImageCopy(types: ["public.tiff"], text: nil, hasFiles: false))
        #expect(ClipboardFilter.isImageCopy(types: ["public.png", "public.utf8-plain-text"], text: "  \n", hasFiles: false))
        #expect(!ClipboardFilter.isImageCopy(types: ["public.png", "public.file-url"], text: nil, hasFiles: true))
        #expect(!ClipboardFilter.isImageCopy(types: ["public.utf8-plain-text"], text: nil, hasFiles: false))
    }

    @Test(arguments: [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
    ])
    func `ignores clips marked as secret or temporary`(marker: String) {
        #expect(ClipboardFilter.shouldIgnore(types: ["public.utf8-plain-text", marker], text: "hunter2", hasFiles: false))
    }

    @Test func `ignores whitespace-only text`() {
        #expect(ClipboardFilter.shouldIgnore(types: ["public.utf8-plain-text"], text: " \n\t ", hasFiles: false))
    }

    @Test func `keeps ordinary text`() {
        #expect(!ClipboardFilter.shouldIgnore(types: ["public.utf8-plain-text"], text: "hello", hasFiles: false))
    }

    @Test func `keeps files even without text`() {
        #expect(!ClipboardFilter.shouldIgnore(types: ["public.file-url"], text: nil, hasFiles: true))
    }
}

struct SnapshotTypesTests {
    @Test func `a TIFF next to a PNG is skipped and offered again lazily`() {
        let types = ["public.png", "Apple PNG pasteboard type", "public.tiff", "NeXT TIFF v4.0 pasteboard type"]
        let plan = ClipboardFilter.snapshotTypes(types)
        #expect(plan.copy == ["public.png", "Apple PNG pasteboard type"])
        #expect(plan.lazyTIFF)
    }

    @Test func `a TIFF alone and other types are copied as they are`() {
        #expect(ClipboardFilter.snapshotTypes(["public.tiff"]) == (["public.tiff"], false))
        #expect(ClipboardFilter.snapshotTypes(["public.utf8-plain-text", "public.rtf"]) == (["public.utf8-plain-text", "public.rtf"], false))
    }
}

struct PlainTextTests {
    @Test func `plain text of a clip`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder.url)
        let rich = try await store.save(ClipDraft(text: "Hello bold", kind: .richText,
            representations: [ClipRepresentation(type: "public.rtf", data: Data("{\\rtf1 Hello \\b bold}".utf8))], sourceBundleID: nil, date: .now))
        #expect(rich.plainText == "Hello bold")
        let files = try await store.save(ClipDraft(text: "/tmp/a.txt\n/tmp/b.txt", kind: .files, representations: [], sourceBundleID: nil, date: .now))
        #expect(files.plainText == "/tmp/a.txt\n/tmp/b.txt")
        let image = try #require(ClipImage.make(from: makeImageData(width: 10, height: 10)))
        let picture = try await store.save(ClipDraft(text: image.description, kind: .image, representations: [], sourceBundleID: nil, date: .now, image: image))
        #expect(picture.plainText == nil)
    }
}
