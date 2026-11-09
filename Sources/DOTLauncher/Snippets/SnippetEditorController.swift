import AppKit
import DOTLauncherCore
import SwiftUI

/// A small floating window for creating and editing a snippet. Like the
/// launcher it never activates DOT, so the app underneath stays frontmost.
final class SnippetEditorController: NSObject, NSWindowDelegate {
    private let library: SnippetLibrary
    private var panel: NSPanel?
    private var confirmation = PressConfirmation()

    private let theme: ThemeController

    init(library: SnippetLibrary, theme: ThemeController) {
        self.library = library
        self.theme = theme
    }

    /// Opens the editor for `snippet`, or for a new one when nil.
    func open(_ snippet: Snippet?) {
        close()
        let draft = SnippetDraft(snippet)
        let view = SnippetEditorView(
            draft: draft,
            save: { [weak self] in self?.save(draft) },
            cancel: { [weak self] in self?.close() },
            delete: { [weak self] in self?.delete(draft) }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = snippet == nil ? "New Snippet" : "Edit Snippet"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ThemedRoot(theme: theme, content: view))
        theme.register(panel)
        panel.delegate = self
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        confirmation.reset()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }

    private func save(_ draft: SnippetDraft) {
        guard draft.canSave else { return }
        library.save(draft.snippet())
        close()
    }

    private func delete(_ draft: SnippetDraft) {
        guard let original = draft.original else { return }
        guard confirmation.press(original.id.uuidString, at: .now) else {
            draft.deleteArmed = true
            return
        }
        library.delete(original.id)
        close()
    }
}
