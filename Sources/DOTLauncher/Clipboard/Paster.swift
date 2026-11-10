import AppKit
import DOTLauncherCore

/// Puts a stored clip back on the pasteboard and pastes it into the app
/// that was frontmost before the launcher opened. Unlike TextPaster, the
/// clip stays on the clipboard afterwards (it was copied by the user).
enum Paster {
    /// Writes the clip, then posts ⌘V when Accessibility is granted.
    /// Returns false when it could only copy.
    @discardableResult
    static func paste(_ item: ClipItem, representations: [ClipRepresentation], imageURL: URL?, monitor: PasteboardMonitor) -> Bool {
        guard write(item, representations: representations, imageURL: imageURL) else {
            Log.clipboard.notice("not pasted: the image file is missing")
            return false
        }
        monitor.ignoreOwnWrite()

        guard KeyboardPaste.canPost else {
            Log.clipboard.notice("copied only: Accessibility is not granted, so ⌘V cannot be sent")
            AccessibilityPermission.prompt()
            return false
        }

        Task {
            // Give the panel time to order out so the target window is key again.
            try? await Task.sleep(for: .milliseconds(80))
            KeyboardPaste.send()
        }
        return true
    }

    /// False when an image clip's file is gone (nothing is written then).
    private static func write(_ item: ClipItem, representations: [ClipRepresentation], imageURL: URL?) -> Bool {
        let pasteboard = NSPasteboard.general

        if item.kind == .image {
            guard let imageURL, let png = try? Data(contentsOf: imageURL) else { return false }
            pasteboard.clearContents()
            // PNG for modern apps, TIFF for the ones that only read that.
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiff = NSImage(data: png)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            return true
        }

        pasteboard.clearContents()
        if item.kind == .files {
            let urls = item.text.split(separator: "\n").map { URL(filePath: String($0)) as NSURL }
            pasteboard.writeObjects(urls)
            return true
        }

        let types = representations.map { NSPasteboard.PasteboardType($0.type) }
        pasteboard.declareTypes(types.isEmpty ? [.string] : types, owner: nil)
        for representation in representations {
            pasteboard.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
        }
        if !types.contains(.string) {
            pasteboard.setString(item.text, forType: .string)
        }
        return true
    }
}
