import AppKit
import Carbon.HIToolbox
import DOTLauncherCore

/// Puts a stored clip back on the pasteboard and pastes it into the app
/// that was frontmost before the launcher opened.
enum Paster {
    /// Writes the clip, then posts ⌘V when Accessibility is granted.
    /// Returns false when it could only copy.
    @discardableResult
    static func paste(_ item: ClipItem, representations: [ClipRepresentation], monitor: PasteboardMonitor) -> Bool {
        write(item, representations: representations)
        monitor.ignoreOwnWrite()

        guard AccessibilityPermission.isGranted, CGPreflightPostEventAccess() else {
            Log.clipboard.notice("copied only: Accessibility is not granted, so ⌘V cannot be sent")
            AccessibilityPermission.prompt()
            return false
        }

        Task {
            // Give the panel time to order out so the target window is key again.
            try? await Task.sleep(for: .milliseconds(80))
            postCommandV()
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

    /// kVK_ANSI_V is the physical V key on ANSI layouts; non-QWERTY
    /// layouts may need a lookup through the current keyboard layout.
    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
