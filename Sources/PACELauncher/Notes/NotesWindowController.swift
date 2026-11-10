import AppKit
import SwiftUI

/// A floating notes window. Non-activating like the launcher, so the app
/// you were in stays frontmost while you jot something down.
final class NotesWindowController: NSObject, NSWindowDelegate {
    let model: NotesModel
    private var panel: NotesPanel?
    private weak var textView: NSTextView?

    private let theme: ThemeController

    init(model: NotesModel, theme: ThemeController) {
        self.model = model
        self.theme = theme
    }

    /// Shows the window on the current note, or the latest one.
    func show() {
        if model.currentID == nil {
            model.openLatest()
        }
        present()
    }

    func show(note: UUID) {
        if model.currentID != note {
            model.open(note)
        }
        present()
    }

    func showNew() {
        model.createNew()
        present()
    }

    func windowWillClose(_ notification: Notification) {
        model.flush()
        model.showingSwitcher = false
    }

    private func present() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        // On first open SwiftUI creates the text view during layout, after
        // this call; focusText runs again from onCreate in that case.
        focusText()
    }

    private func focusText() {
        guard let panel, let textView, panel.isVisible else { return }
        panel.makeFirstResponder(textView)
    }

    private func makePanel() -> NotesPanel {
        let panel = NotesPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "PACE Notes"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 300, height: 240)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ThemedRoot(theme: theme, content: NotesView(model: model) { [weak self] textView in
            self?.textView = textView
            Task { self?.focusText() }
        }))
        theme.register(panel)
        if !panel.setFrameUsingName("PACENotesWindow") {
            panel.center()
        }
        panel.setFrameAutosaveName("PACENotesWindow")

        panel.onKeyEquivalent = { [weak self] shortcut in
            guard let model = self?.model else { return false }
            if shortcut == .command("n") {
                model.createNew()
            } else if shortcut == .command("p") {
                model.showingSwitcher.toggle()
            } else if shortcut == .delete {
                model.requestTrashCurrent()
            } else {
                return false
            }
            return true
        }
        return panel
    }
}

/// Routes ⌘N, ⌘P and ⌃X before the text view sees them.
final class NotesPanel: NSPanel {
    var onKeyEquivalent: ((KeyShortcut) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           !event.modifierFlags.intersection([.command, .control]).isEmpty,
           let shortcut = KeyShortcut(event: event),
           onKeyEquivalent?(shortcut) == true {
            return
        }
        super.sendEvent(event)
    }
}
