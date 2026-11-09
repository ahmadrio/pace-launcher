import AppKit

/// The menu bar icon and its menu. The menu is rebuilt each time it opens,
/// so status lines are always current.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let hotKeys: HotKeyCenter
    private let clipboardAccess: () -> PasteboardMonitor.Access?
    private let openLauncher: () -> Void
    private let enableAnyway: (String) -> Void

    init(
        hotKeys: HotKeyCenter,
        clipboardAccess: @escaping () -> PasteboardMonitor.Access?,
        openLauncher: @escaping () -> Void,
        enableAnyway: @escaping (String) -> Void
    ) {
        self.hotKeys = hotKeys
        self.clipboardAccess = clipboardAccess
        self.openLauncher = openLauncher
        self.enableAnyway = enableAnyway
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
        for entry in hotKeys.entries {
            let title = "\(entry.combo.displayString)  \(entry.name)"
            switch entry.status {
            case .registered:
                addInfo(title)
            case .unavailable(let code):
                addInfo("\(title) — in use by another app (\(code))")
            case .disabled(let reason):
                let item = addItem("\(title) — \(reason). Enable anyway", action: #selector(enable(_:)))
                item.representedObject = entry.name
            }
        }

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
        addItem("Quit DOT Launcher", action: #selector(quit), key: "q")
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
        guard let name = sender.representedObject as? String else { return }
        enableAnyway(name)
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
