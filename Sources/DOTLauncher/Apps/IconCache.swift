import AppKit

/// Finder icons by file path, loaded lazily and kept for the app's lifetime.
final class IconCache {
    private var images: [String: NSImage] = [:]

    func icon(forPath path: String) -> NSImage {
        if let cached = images[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        images[path] = image
        return image
    }
}
