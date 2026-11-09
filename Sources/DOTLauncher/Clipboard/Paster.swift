import AppKit
import DOTLauncherCore

/// Puts a stored clip back on the pasteboard and pastes it into the app
/// that was frontmost before the launcher opened. Unlike TextPaster, the
/// clip stays on the clipboard afterwards (it was copied by the user).
enum Paster {
    /// Writes the clip, then posts ⌘V when Accessibility is granted.
    /// Returns false when it could only copy.
    @discardableResult
    static func paste(_ item: ClipItem, representations: [ClipRepresentation], monitor: PasteboardMonitor) -> Bool {
        write(item, representations: representations)
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

    private static func write(_ item: ClipItem, representations: [ClipRepresentation]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.kind == .files {
            let urls = item.text.split(separator: "\n").map { URL(filePath: String($0)) as NSURL }
            pasteboard.writeObjects(urls)
            return
        }

        let types = representations.map { NSPasteboard.PasteboardType($0.type) }
        pasteboard.declareTypes(types.isEmpty ? [.string] : types, owner: nil)
        for representation in representations {
            pasteboard.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
        }
        if !types.contains(.string) {
            pasteboard.setString(item.text, forType: .string)
        }
    }
}
