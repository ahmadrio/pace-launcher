import AppKit
import PACELauncherCore
import SwiftUI

/// The welcome window: shown once per Mac on first launch, and again from
/// the menu bar or the launcher. Like Settings it activates PACE, and
/// closing it hands focus back.
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private let status: PermissionStatus
    private let settings: SettingsStore
    private let hotKeys: HotKeyCenter
    private let updates: UpdateChecker
    private let openLauncher: () -> Void
    private let openShortcuts: () -> Void
    private var window: NSWindow?

    init(
        settings: SettingsStore, hotKeys: HotKeyCenter, autoExpand: AutoExpandController,
        clipboardAccess: @escaping () -> PasteboardMonitor.Access?, updates: UpdateChecker,
        openLauncher: @escaping () -> Void, openShortcuts: @escaping () -> Void
    ) {
        status = PermissionStatus(settings: settings, autoExpand: autoExpand, clipboardAccess: clipboardAccess)
        self.settings = settings
        self.hotKeys = hotKeys
        self.updates = updates
        self.openLauncher = openLauncher
        self.openShortcuts = openShortcuts
    }

    /// From show() until the window closes, even while PACE is hidden:
    /// update checks wait and the launcher must not hide PACE meanwhile.
    private(set) var isOpen = false

    /// Shows the window unless this Mac has seen it. Test data folders use
    /// their own flag, so a test run never uses up the real first launch.
    func showIfFirstLaunch() {
        let key = MachineDefaults.key("welcomeShown", usingTestFolders: AppPaths.isUsingTestFolders)
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        Log.app.notice("showing the welcome window (first launch)")
        show()
    }

    func show() {
        isOpen = true
        status.startWatching()
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        isOpen = false
        status.stopWatching()
        let closing = window
        let otherWindowOpen = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && !($0 is NSPanel) && $0.styleMask.contains(.titled)
        }
        if !otherWindowOpen { NSApp.deactivate() }
        // After the close finishes: the update check waits while this is open.
        Task { [updates] in updates.checkIfDue() }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to PACE Launcher"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let version = updates.current?.description ?? "unknown"
        window.contentView = NSHostingView(rootView: WelcomeView(
            status: status, settings: settings, hotKeys: hotKeys, version: version,
            openPermission: Self.openSettings(for:),
            openLauncher: { [weak self] in
                self?.window?.close()
                self?.openLauncher()
            },
            openShortcuts: { [weak self] in self?.openShortcuts() },
            done: { [weak self] in self?.window?.close() }
        ))
        window.center()
        return window
    }

    /// The System Settings pane for a permission (macOS prompts first where
    /// it can).
    private static func openSettings(for kind: PermissionKind) {
        switch kind {
        case .accessibility:
            AccessibilityPermission.prompt()
            AccessibilityPermission.openSettings()
        case .inputMonitoring:
            KeystrokeMonitor.requestPermission()
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        case .clipboard:
            open("x-apple.systempreferences:com.apple.preference.security")
        case .automation:
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        }
    }

    private static func open(_ link: String) {
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
