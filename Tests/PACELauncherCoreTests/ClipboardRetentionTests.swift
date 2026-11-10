import Foundation
import Testing
@testable import PACELauncherCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let old = now.addingTimeInterval(-10 * 86_400)

private func text(_ value: String, at date: Date) -> ClipDraft {
    ClipDraft(text: value, kind: .text, representations: [], sourceBundleID: nil, date: date)
}

struct ClipboardRetentionTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "PACELauncherTests-retention-\(UUID().uuidString)")

    @Test func `pruning keeps pinned clips and removes image files`() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        try await store.save(text("old unpinned", at: old))
        let pinned = try await store.save(text("old pinned", at: old))
        try await store.setPinned(pinned.id, true)
        let image = try #require(ClipImage.make(from: makeImageData(width: 30, height: 20)))
        let picture = try await store.save(ClipDraft(text: image.description, kind: .image, representations: [], sourceBundleID: nil, date: old, image: image))
        let pictureFile = try #require(store.imageURL(for: picture))
        try await store.save(text("new", at: now))

        let removed = try await store.prune(lastUsedBefore: now.addingTimeInterval(-7 * 86_400))

        #expect(removed == 2)
        #expect(Set(try await store.recent().map(\.text)) == ["old pinned", "new"])
        #expect(!FileManager.default.fileExists(atPath: pictureFile.path))
    }

    @Test func `counting matches what pruning would remove`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        try await store.save(text("old unpinned", at: old))
        let pinned = try await store.save(text("old pinned", at: old))
        try await store.setPinned(pinned.id, true)
        try await store.save(text("new", at: now))
        let cutoff = now.addingTimeInterval(-7 * 86_400)

        #expect(try await store.countUnpinned(lastUsedBefore: cutoff) == 1)
        #expect(try await store.prune(lastUsedBefore: cutoff) == 1)
        #expect(try await store.countUnpinned(lastUsedBefore: cutoff) == 0)
    }

    @Test func `pruning keeps a pinned image clip's files`() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        let image = try #require(ClipImage.make(from: makeImageData(width: 30, height: 20)))
        let picture = try await store.save(ClipDraft(text: image.description, kind: .image, representations: [], sourceBundleID: nil, date: old, image: image))
        try await store.setPinned(picture.id, true)
        let pictureFile = try #require(store.imageURL(for: picture))
        let thumbnailFile = try #require(store.thumbnailURL(for: picture))

        #expect(try await store.prune(lastUsedBefore: now) == 0)
        #expect(FileManager.default.fileExists(atPath: pictureFile.path))
        #expect(FileManager.default.fileExists(atPath: thumbnailFile.path))
    }

    @Test func `clear history keeps pinned clips`() async throws {
        let store = try ClipboardStore(path: ":memory:")
        try await store.save(text("a", at: now))
        try await store.save(text("b", at: now))
        let keep = try await store.save(text("keep", at: now))
        try await store.setPinned(keep.id, true)

        #expect(try await store.clearUnpinned() == 2)
        #expect(try await store.recent().map(\.text) == ["keep"])
    }

    @Test func `retention cutoffs`() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(ClipboardRetention.forever.cutoff(now: now, calendar: calendar) == nil)
        #expect(ClipboardRetention.week.cutoff(now: now, calendar: calendar) == now.addingTimeInterval(-7 * 86_400))
        #expect(ClipboardRetention.day.cutoff(now: now, calendar: calendar) == now.addingTimeInterval(-86_400))
        #expect(ClipboardRetention.year.cutoff(now: now, calendar: calendar) == calendar.date(byAdding: .year, value: -1, to: now))
        #expect(ClipboardRetention.allCases.map(\.title) == ["Forever", "1 year", "6 months", "3 months", "1 month", "1 week", "1 day"])
    }
}
