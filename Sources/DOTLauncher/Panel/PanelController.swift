import AppKit
import SwiftUI

/// Shows and hides the launcher panel. Never activates DOT Launcher itself,
/// so the app the user was in stays frontmost.
final class PanelController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 720, height: 460)

    let model: LauncherModel
    private let panel: LauncherPanel

    /// The app that was frontmost when the panel was opened: the target for
    /// paste and window commands.
    private(set) var targetApp: NSRunningApplication?

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()

        let hosting = NSHostingView(rootView: LauncherView(model: model))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: Self.size))
        glass.cornerRadius = 24
        // Plain glass lets busy windows behind show through; tint it with
        // the (light/dark aware) window background so text stays legible.
        glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6)
        glass.contentView = hosting
        hosting.frame = glass.bounds
        panel.contentView = glass
        panel.delegate = self

        model.close = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApp = front
        }
        model.reset()
        position()
        panel.makeKeyAndOrderFront(nil)
        if let field = model.searchField {
            panel.makeFirstResponder(field)
        }
        Log.panel.info("shown; key=\(self.panel.isKeyWindow) target=\(self.targetApp?.bundleIdentifier ?? "none", privacy: .public)")
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        Log.panel.info("hidden")
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    /// Centers the panel horizontally, slightly above the middle of the
    /// screen under the mouse (NSScreen.main is unreliable without a key window).
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main ?? NSScreen.screens.first
        else { return }

        let visible = screen.visibleFrame
        let x = visible.midX - Self.size.width / 2
        let y = max(visible.minY, visible.maxY - visible.height * 0.18 - Self.size.height)
        panel.setFrame(NSRect(x: x.rounded(), y: y.rounded(), width: Self.size.width, height: Self.size.height), display: false)
    }
}
