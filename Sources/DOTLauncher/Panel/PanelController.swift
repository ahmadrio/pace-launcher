import AppKit
import SwiftUI

/// Shows and hides the launcher panel. Never activates DOT Launcher itself,
/// so the app the user was in stays frontmost.
final class PanelController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 720, height: 460)
    private static let cornerRadius: CGFloat = 24

    let model: LauncherModel
    private let panel: LauncherPanel

    /// The app that was frontmost when the panel was opened: the target for
    /// paste and window commands.
    private(set) var targetApp: NSRunningApplication?

    /// False while another DOT window (Settings) needs the app to stay active.
    var canHideApp: () -> Bool = { true }

    /// Called every time the panel opens, before results are computed.
    var onShow: (() -> Void)?

    init(model: LauncherModel, theme: ThemeController) {
        self.model = model
        panel = LauncherPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()

        let hosting = NSHostingView(rootView: ThemedRoot(theme: theme, content: LauncherView(model: model)))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: Self.size))
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hosting
        hosting.frame = glass.bounds
        glass.autoresizingMask = [.width, .height]

        // A panel that can become key gets a system rim that cuts the glass
        // corners with a jagged, tighter curve, unless the content is
        // clipped to the same rounded shape.
        let container = NSView(frame: glass.frame)
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.addSubview(glass)
        panel.contentView = container
        // Glass density (tint) and light/dark come from the theme.
        theme.register(panel, glass: glass, content: hosting)
        panel.delegate = self

        model.close = { [weak self] in self?.hide() }
        panel.onKeyEquivalent = { [weak model] event in
            guard let model, let shortcut = KeyShortcut(event: event) else { return false }
            return model.handle(shortcut)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(mode: LauncherModel.Mode = .root) {
        if isVisible, model.mode == mode {
            hide()
        } else {
            show(mode: mode)
        }
    }

    func show(mode: LauncherModel.Mode = .root) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApp = front
        }
        onShow?()
        model.reset(to: mode)
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
        // Reopening the app (Finder, `open`) activates DOT; hand focus back
        // to the previous app, as if DOT had never been activated.
        if NSApp.isActive, canHideApp() {
            NSApp.hide(nil)
        }
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
