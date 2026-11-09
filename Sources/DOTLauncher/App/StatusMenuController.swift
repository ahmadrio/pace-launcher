import AppKit

/// The menu bar icon and its menu. The menu is rebuilt each time it opens,
/// so status lines are always current.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let hotKeys: HotKeyCenter
    private let blockedGroups: () -> [GatedHotKey.Blocker]
    private let clipboardAccess: () -> PasteboardMonitor.Access?
    private let openLauncher: () -> Void
    private let enableAnyway: (GatedHotKey.Blocker) -> Void
    private let hideIcon: () -> Void

    init(
        hotKeys: HotKeyCenter,
        blockedGroups: @escaping () -> [GatedHotKey.Blocker],
        clipboardAccess: @escaping () -> PasteboardMonitor.Access?,
        openLauncher: @escaping () -> Void,
        enableAnyway: @escaping (GatedHotKey.Blocker) -> Void,
        hideIcon: @escaping () -> Void
    ) {
        self.hotKeys = hotKeys
        self.blockedGroups = blockedGroups
        self.clipboardAccess = clipboardAccess
        self.openLauncher = openLauncher
        self.enableAnyway = enableAnyway
        self.hideIcon = hideIcon
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "DOT Launcher")
        }
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        addItem("Open DOT Launcher   \(AppDelegate.launcherHotKey.displayString)", action: #selector(open))
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: "Shortcuts"))
        for blocker in blockedGroups() {
            let item = addItem("\(blocker.group): off while \(blocker.appName) runs — Enable anyway", action: #selector(enable(_:)))
            item.representedObject = blocker
        }
        let all = NSMenuItem(title: "All Shortcuts", action: nil, keyEquivalent: "")
        all.submenu = shortcutsSubmenu()
        menu.addItem(all)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Permissions"))
        if AccessibilityPermission.isGranted {
            addInfo("Accessibility: granted")
        } else {
            addItem("Accessibility: not granted — Open Settings…", action: #selector(openAccessibility))
        }
        switch clipboardAccess() {
        case .recording?:
            addInfo("Clipboard history: recording")
        case .needsPermission?:
            addItem("Clipboard history: paused — allow “Paste from other apps”…", action: #selector(openPrivacy))
        case .denied?:
            addItem("Clipboard history: blocked — Open Settings…", action: #selector(openPrivacy))
        case nil:
            addInfo("Clipboard history: unavailable")
        }

        menu.addItem(.separator())
        if LoginItem.isInstalled {
            let login = addItem("Launch at Login", action: #selector(toggleLoginItem))
            login.state = LoginItem.isEnabled ? .on : .off
        } else {
            addInfo("Launch at Login: run `make run` to install first")
        }
        addItem("Hide Menu Bar Icon", action: #selector(hideMenuBarIcon))
        addItem("Quit DOT Launcher", action: #selector(quit), key: "q")
    }

    /// Hiding keeps everything reachable through launcher commands.
    func setIconVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    @objc private func hideMenuBarIcon() {
        hideIcon()
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    private func shortcutsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for entry in hotKeys.entries {
            let state = switch entry.status {
            case .registered: ""
            case .unavailable(let code): " — in use by another app (\(code))"
            case .disabled(let reason): " — \(reason)"
            }
            let item = NSMenuItem(title: "\(entry.combo.displayString)\t\(entry.name)\(state)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
        return submenu
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func addInfo(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @objc private func open() {
        openLauncher()
    }

    @objc private func enable(_ sender: NSMenuItem) {
        guard let blocker = sender.representedObject as? GatedHotKey.Blocker else { return }
        enableAnyway(blocker)
    }

    @objc private func openAccessibility() {
        AccessibilityPermission.prompt()
        AccessibilityPermission.openSettings()
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
