import AppKit
import SwiftUI

/// The Settings window. Unlike the panels it activates DOT, since forms,
/// pickers and color wells need normal focus; closing it hands focus back.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model = SettingsWindowModel()
    private let settings: SettingsStore
    private let scripts: ScriptLibrary
    private let autoExpand: AutoExpandController
    private let sync: SyncController
    private let shortcuts: ShortcutRecorder
    private let clipboard: ClipboardMaintenance
    private let quicklinks: QuicklinkEditor
    private var window: NSWindow?

    init(settings: SettingsStore, scripts: ScriptLibrary, autoExpand: AutoExpandController, sync: SyncController, shortcuts: ShortcutRecorder, clipboard: ClipboardMaintenance) {
        self.settings = settings
        self.scripts = scripts
        self.autoExpand = autoExpand
        self.sync = sync
        self.shortcuts = shortcuts
        self.clipboard = clipboard
        quicklinks = QuicklinkEditor(settings: settings)
    }

    var isVisible: Bool { window?.isVisible ?? false }

    /// `addQuicklink` opens Quicklinks with an empty form ("Create Quicklink").
    func show(section: SettingsSection = .general, addQuicklink: Bool = false) {
        model.section = addQuicklink ? .quicklinks : section
        if addQuicklink { quicklinks.startAdding() }
        // Shortcuts › Scripts lists what is on disk now.
        scripts.reload()
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // A form left open would come back days later and could overwrite newer data.
        quicklinks.cancel()
        shortcuts.stop()
        NSApp.deactivate()
    }

    /// Leaving Settings (another app, the launcher, Notes) ends a pending
    /// shortcut recording, so DOT's hotkeys never stay paused.
    func windowDidResignKey(_ notification: Notification) {
        shortcuts.stop()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DOT Launcher Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        shortcuts.window = window
        window.contentView = NSHostingView(rootView: SettingsView(model: model, settings: settings, scripts: scripts, autoExpand: autoExpand, sync: sync, shortcuts: shortcuts, clipboard: clipboard, quicklinks: quicklinks))
        if !window.setFrameUsingName("DOTSettingsWindow") {
            window.center()
        }
        window.setFrameAutosaveName("DOTSettingsWindow")
        return window
    }
}
