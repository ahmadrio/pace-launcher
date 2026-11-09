import AppKit

/// Text output from DOT (snippets, translations, AI answers).
enum TextPaster {
    /// Permanent: the text stays on the clipboard and lands in history.
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Temporary: pastes into the frontmost app, then puts the previous
    /// clipboard back. Neither write is recorded in history. Without the
    /// Accessibility grant it falls back to a permanent copy.
    static func paste(_ text: String, monitor: PasteboardMonitor?) {
        guard KeyboardPaste.canPost else {
            Log.clipboard.notice("copied only: Accessibility is not granted, so ⌘V cannot be sent")
            copy(text)
            AccessibilityPermission.prompt()
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor?.ignoreOwnWrite()
        let ourChange = pasteboard.changeCount

        Task {
            // Let the panel order out so the target window is key again.
            try? await Task.sleep(for: .milliseconds(80))
            KeyboardPaste.send()
            // The target app reads the pasteboard asynchronously; give it time.
            try? await Task.sleep(for: .milliseconds(500))
            // If the user copied something new meanwhile, keep that instead.
            guard pasteboard.changeCount == ourChange else { return }
            snapshot.restore(to: pasteboard)
            monitor?.ignoreOwnWrite()
        }
    }
}
