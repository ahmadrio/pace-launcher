import AppKit
import Carbon.HIToolbox

/// Sends ⌘V to the frontmost app.
enum KeyboardPaste {
    /// Posting key events needs the Accessibility grant.
    static var canPost: Bool {
        AccessibilityPermission.isGranted && CGPreflightPostEventAccess()
    }

    /// kVK_ANSI_V is the physical V key on ANSI layouts; non-QWERTY
    /// layouts may need a lookup through the current keyboard layout.
    static func send() {
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
