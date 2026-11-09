import AppKit

/// The menu bar icon and its menu.
final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "DOT Launcher")
        }
        rebuildMenu()
        statusItem.menu = menu
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        menu.addItem(withTitle: "DOT Launcher", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit DOT Launcher", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
