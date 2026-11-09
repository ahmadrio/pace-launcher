import AppKit
import ApplicationServices

/// The Accessibility (TCC) grant needed to move other apps' windows and to
/// post ⌘V into them.
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt (macOS shows it only once per app); after
    /// that, the user has to flip the switch in System Settings.
    static func prompt() {
        // The literal key avoids touching kAXTrustedCheckOptionPrompt, a
        // mutable C global that Swift 6 treats as not concurrency-safe.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
