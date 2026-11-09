import AppKit

/// The menu bar icon and its menu. The menu is rebuilt each time it opens,
/// so status lines are always current.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let hotKeys: HotKeyCenter
    private let openLauncher: () -> Void

    init(hotKeys: HotKeyCenter, openLauncher: @escaping () -> Void) {
        self.hotKeys = hotKeys
        self.openLauncher = openLauncher
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "DOT Launcher")
        }
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let launcherHotKey = AppDelegate.launcherHotKey.displayString
        addItem("Open DOT Launcher   \(launcherHotKey)", action: #selector(open))
        menu.addItem(.separator())

        menu.addItem(sectionHeader("Shortcuts"))
        for entry in hotKeys.entries {
            let state: String = switch entry.status {
            case .registered: "on"
            case .unavailable(let code): "in use (\(code))"
            case .disabled(let reason): reason
            }
            let item = NSMenuItem(title: "\(entry.combo.displayString)  \(entry.name) — \(state)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        addItem("Quit DOT Launcher", action: #selector(quit), key: "q")
    }

    private func addItem(_ title: String, action: Selector, key: String = "") {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        NSMenuItem.sectionHeader(title: title)
    }

    @objc private func open() {
        openLauncher()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
