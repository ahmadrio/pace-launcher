import AppKit
import SwiftUI

/// A small, click-through message near the bottom of the screen, used for
/// scripts in compact and silent mode.
final class HUDController {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    /// The message on screen; nil once hidden.
    private(set) var currentText: String?

    func show(_ text: String, isError: Bool, duration: TimeInterval = 2.2) {
        hideTask?.cancel()
        currentText = text
        let panel = panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: HUDView(text: text, isError: isError))
        panel.contentView = host
        // fittingSize lays the text out on one line; a message wider than
        // the HUD gets the height of its wrapped lines instead.
        var size = host.fittingSize
        if size.width >= HUDView.maxWidth {
            size = NSHostingController(rootView: host.rootView).sizeThatFits(in: NSSize(width: HUDView.maxWidth, height: 400))
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 90, width: size.width, height: size.height), display: true)
        }
        panel.orderFrontRegardless()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
        currentText = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct HUDView: View {
    static let maxWidth: CGFloat = 520

    let text: String
    let isError: Bool

    var body: some View {
        Label(text.isEmpty ? "Done" : String(text.prefix(140)), systemImage: isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isError ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: Self.maxWidth)
            .glassEffect(in: .capsule)
    }
}
