import AppKit

/// A borderless floating panel that takes keyboard focus without
/// activating DOT Launcher, so the app underneath stays frontmost and
/// remains the target for paste and window commands.
final class LauncherPanel: NSPanel {
    init(contentRect: NSRect) {
        // .nonactivatingPanel must be set at init; toggling it later does
        // not update the window server tag.
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
    }

    // Borderless windows refuse key status by default.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
