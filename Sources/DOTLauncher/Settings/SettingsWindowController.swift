import AppKit
import SwiftUI

/// The Settings window. Unlike the panels it activates DOT, since forms,
/// pickers and color wells need normal focus; closing it hands focus back.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model = SettingsWindowModel()
    private let settings: SettingsStore
    private let scripts: ScriptLibrary
    private let autoExpand: AutoExpandController
    private var window: NSWindow?

    init(settings: SettingsStore, scripts: ScriptLibrary, autoExpand: AutoExpandController) {
        self.settings = settings
        self.scripts = scripts
        self.autoExpand = autoExpand
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
        NSApp.deactivate()
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
        window.contentView = NSHostingView(rootView: SettingsView(model: model, settings: settings, scripts: scripts, autoExpand: autoExpand))
        if !window.setFrameUsingName("DOTSettingsWindow") {
            window.center()
        }
        window.setFrameAutosaveName("DOTSettingsWindow")
        return window
    }
}
