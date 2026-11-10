import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import DOTLauncherCore

/// Encodes a solid-colour image of the given size as PNG or TIFF.
func makeImageData(width: Int, height: Int, type: String = "public.tiff") -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, type as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

private func pixelSize(of data: Data) -> (Int, Int)? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    return (image.width, image.height)
}

struct ClipImageTests {
    @Test func `converts a TIFF to PNG and keeps its size`() throws {
        let image = try #require(ClipImage.make(from: makeImageData(width: 300, height: 200)))
        #expect(image.png.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(image.width == 300)
        #expect(image.height == 200)
        #expect(pixelSize(of: image.png)?.0 == 300)
    }

    @Test func `the thumbnail fits in 128 pixels`() throws {
        let image = try #require(ClipImage.make(from: makeImageData(width: 300, height: 200, type: "public.png")))
        let size = try #require(pixelSize(of: image.thumbnail))
        #expect(max(size.0, size.1) <= ClipImage.thumbnailSize)
        #expect(max(size.0, size.1) >= 100)
    }

    @Test func `images over the size limit are refused`() {
        #expect(ClipImage.make(from: makeImageData(width: 300, height: 200), maxBytes: 10) == nil)
    }

    @Test func `unreadable data is refused`() {
        #expect(ClipImage.make(from: Data("not an image".utf8)) == nil)
    }

    @Test func `describes itself with its size`() throws {
        let image = try #require(ClipImage.make(from: makeImageData(width: 300, height: 200)))
        #expect(image.description == "Image 300 × 200")
    }

    @Test func `a long text preview shows only its beginning`() {
        let long = String(repeating: "abcdefghij", count: 10_000)
        let preview = ClipStats.preview(of: long, limit: 2_000)
        #expect(preview.text.count == 2_000)
        #expect(preview.isTruncated)
        #expect(long.hasPrefix(preview.text))

        let short = ClipStats.preview(of: "hello", limit: 2_000)
        #expect(short.text == "hello")
        #expect(!short.isTruncated)
    }

    @Test func `the preview image is downsampled from the file`() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-preview-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeImageData(width: 3000, height: 2000, type: "public.png").write(to: url)

        let image = try #require(ClipImage.preview(at: url, maxPixelSize: 800))
        #expect(max(image.width, image.height) == 800)
        #expect(ClipImage.preview(at: url.appending(path: "missing"), maxPixelSize: 800) == nil)
    }

    @Test func `stats count characters and lines`() {
        #expect(ClipStats.summary(for: "a") == "1 character")
        #expect(ClipStats.summary(for: "ab\ncd") == "5 characters · 2 lines")
        #expect(ClipStats.summary(for: "hello") == "5 characters")
    }
}

struct ClipboardImageStoreTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "DOTLauncherTests-images-\(UUID().uuidString)")

    private func imageDraft(width: Int = 300, height: Int = 200, at date: Date = Date(timeIntervalSince1970: 1_800_000_000)) throws -> ClipDraft {
        let image = try #require(ClipImage.make(from: makeImageData(width: width, height: height)))
        return ClipDraft(text: image.description, kind: .image, representations: [], sourceBundleID: "com.apple.Preview", date: date, image: image)
    }

    @Test func `saving an image writes the picture and its thumbnail`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        let item = try await store.save(imageDraft())

        #expect(item.kind == .image)
        #expect(item.text == "Image 300 × 200")
        let png = try #require(store.imageURL(for: item))
        let thumb = try #require(store.thumbnailURL(for: item))
        #expect(png.lastPathComponent == item.hash + ".png")
        #expect(thumb.lastPathComponent == item.hash + "-thumb.png")
        #expect(pixelSize(of: try Data(contentsOf: png))?.0 == 300)
    }

    @Test func `the same image copied again is bumped, not duplicated`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        try await store.save(imageDraft())
        try await store.save(imageDraft(at: Date(timeIntervalSince1970: 1_800_000_100)))

        #expect(try await store.count() == 1)
        #expect(try await store.recent().first?.useCount == 2)
    }

    @Test func `different images are different clips`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        try await store.save(imageDraft(width: 300, height: 200))
        try await store.save(imageDraft(width: 10, height: 10))

        #expect(try await store.count() == 2)
    }

    @Test func `deleting an image clip removes its files`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        let item = try await store.save(imageDraft())
        let png = try #require(store.imageURL(for: item))
        let thumb = try #require(store.thumbnailURL(for: item))

        try await store.delete(item.id)

        #expect(!FileManager.default.fileExists(atPath: png.path))
        #expect(!FileManager.default.fileExists(atPath: thumb.path))
    }

    @Test func `a missing image file reports no url`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        let item = try await store.save(imageDraft())
        try FileManager.default.removeItem(at: try #require(store.imageURL(for: item)))

        #expect(store.imageURL(for: item) == nil)
    }

    @Test func `text clips have no image url`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        let item = try await store.save(ClipDraft(text: "hi", kind: .text, representations: [], sourceBundleID: nil, date: .now))

        #expect(store.imageURL(for: item) == nil)
        #expect(store.thumbnailURL(for: item) == nil)
    }

    @Test func `image clips are found by their description`() async throws {
        let store = try ClipboardStore(path: ":memory:", imagesDirectory: folder)
        try await store.save(imageDraft())

        #expect(try await store.search("Image 300").map(\.kind) == [.image])
    }
}
