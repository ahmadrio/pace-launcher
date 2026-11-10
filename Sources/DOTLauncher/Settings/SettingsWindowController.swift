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
    private var window: NSWindow?

    init(settings: SettingsStore, scripts: ScriptLibrary, autoExpand: AutoExpandController, sync: SyncController, shortcuts: ShortcutRecorder) {
        self.settings = settings
        self.scripts = scripts
        self.autoExpand = autoExpand
        self.sync = sync
        self.shortcuts = shortcuts
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show(section: SettingsSection = .general) {
        model.section = section
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
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
        window.contentView = NSHostingView(rootView: SettingsView(model: model, settings: settings, scripts: scripts, autoExpand: autoExpand, sync: sync, shortcuts: shortcuts))
        if !window.setFrameUsingName("DOTSettingsWindow") {
            window.center()
        }
        window.setFrameAutosaveName("DOTSettingsWindow")
        return window
    }
}
