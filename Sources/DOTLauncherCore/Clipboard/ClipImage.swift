import CoreGraphics
import Foundation
import ImageIO

/// A copied picture, normalised to PNG with a small thumbnail for lists.
public struct ClipImage: Sendable, Equatable {
    /// Larger pasteboard images are not recorded.
    public static let maxSourceBytes = 20 * 1024 * 1024
    /// Longest side of the thumbnail, in pixels.
    public static let thumbnailSize = 128

    public let png: Data
    public let thumbnail: Data
    public let width: Int
    public let height: Int

    /// Converts PNG or TIFF data. Nil when unreadable or over `maxBytes`.
    public static func make(from data: Data, maxBytes: Int = maxSourceBytes) -> ClipImage? {
        guard data.count <= maxBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let png = encodePNG(image),
              let thumbnailPNG = encodePNG(thumbnail)
        else { return nil }
        return ClipImage(png: png, thumbnail: thumbnailPNG, width: image.width, height: image.height)
    }

    /// Searchable text for the clip, such as "Image 1440 × 900".
    public var description: String { "Image \(width) × \(height)" }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
