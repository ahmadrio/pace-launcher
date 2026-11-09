import AppKit

/// A key plus ⌘⌥⌃⇧ modifiers, matched against key-down events in the panel.
struct KeyShortcut: Equatable {
    private static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    let key: String
    let modifiers: NSEvent.ModifierFlags

    init(key: String, modifiers: NSEvent.ModifierFlags) {
        self.key = key.lowercased()
        self.modifiers = modifiers.intersection(Self.relevant)
    }

    /// Nil for key auto-repeats: holding ⌃X must not count as the second
    /// press that confirms a delete.
    init?(event: NSEvent) {
        guard event.type == .keyDown, !event.isARepeat,
              let characters = event.charactersIgnoringModifiers, !characters.isEmpty
        else {
            return nil
        }
        self.init(key: characters, modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    /// "⌃X", "⌘↩", "⇧⌘C", in macOS modifier order.
    var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        switch key {
        case "\r": text += "↩"
        case "\u{7f}": text += "⌫"
        default: text += key.uppercased()
        }
        return text
    }

    static let delete = KeyShortcut(key: "x", modifiers: .control)

    static func command(_ key: String, shift: Bool = false) -> KeyShortcut {
        KeyShortcut(key: key, modifiers: shift ? [.command, .shift] : .command)
    }
}

/// An extra action on a row or a mode, triggered by a shortcut.
struct SecondaryAction {
    let title: String
    let shortcut: KeyShortcut
    /// Requires pressing the shortcut twice (for destructive actions).
    var confirm = false
    let action: LauncherResult.Action
}
