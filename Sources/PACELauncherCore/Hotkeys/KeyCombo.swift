/// A global keyboard shortcut in Carbon terms: a virtual key code plus
/// Carbon modifier bits (the values `RegisterEventHotKey` expects).
public struct KeyCombo: Sendable, Hashable {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32

    // Carbon modifier bits (cmdKey, shiftKey, optionKey, controlKey in
    // HIToolbox/Events.h). Duplicated here so Core does not import Carbon.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Parses strings like "opt+space" or "ctrl+opt+left".
    /// Exactly one non-modifier key is required.
    public init?(_ string: String) {
        var modifiers: UInt32 = 0
        var key: UInt32?

        for raw in string.split(separator: "+") {
            let token = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if let modifier = Self.modifierNames[token] {
                modifiers |= modifier
            } else if let code = Self.keyCodes[token], key == nil {
                key = code
            } else {
                return nil
            }
        }

        guard let key else { return nil }
        self.init(keyCode: key, carbonModifiers: modifiers)
    }

    /// Human-readable form in macOS order: ⌃⌥⇧⌘ then the key.
    public var displayString: String {
        var result = ""
        if carbonModifiers & Self.control != 0 { result += "⌃" }
        if carbonModifiers & Self.option != 0 { result += "⌥" }
        if carbonModifiers & Self.shift != 0 { result += "⇧" }
        if carbonModifiers & Self.command != 0 { result += "⌘" }
        return result + (Self.keySymbols[keyCode] ?? "key \(keyCode)")
    }

    /// The form `init?(_:)` reads back, such as "ctrl+opt+left".
    public var stringValue: String {
        var parts: [String] = []
        if carbonModifiers & Self.control != 0 { parts.append("ctrl") }
        if carbonModifiers & Self.option != 0 { parts.append("opt") }
        if carbonModifiers & Self.shift != 0 { parts.append("shift") }
        if carbonModifiers & Self.command != 0 { parts.append("cmd") }
        parts.append(Self.keyNames[keyCode] ?? "")
        return parts.joined(separator: "+")
    }

    /// Keys PACE can name, show and store (an ANSI layout's keys).
    public var isKnownKey: Bool { Self.keyNames[keyCode] != nil }

    /// F1–F12, which may be used without a modifier.
    public var isFunctionKey: Bool { Self.functionKeyCodes.contains(keyCode) }

    /// True when the same combo is already taken by one of `others`
    /// (for example the enabled system shortcuts).
    public func conflicts(with others: [KeyCombo]) -> Bool {
        others.contains(self)
    }

    // MARK: - Tables

    private static let modifierNames: [String: UInt32] = [
        "cmd": command, "command": command,
        "shift": shift,
        "opt": option, "option": option, "alt": option,
        "ctrl": control, "control": control,
    ]

    /// kVK_* virtual key codes for an ANSI layout.
    private static let namedKeys: [(names: [String], code: UInt32, symbol: String)] = [
        (["space"], 49, "Space"),
        (["return", "enter"], 36, "↩"),
        (["tab"], 48, "⇥"),
        (["escape", "esc"], 53, "⎋"),
        (["delete", "backspace"], 51, "⌫"),
        (["left"], 123, "←"),
        (["right"], 124, "→"),
        (["down"], 125, "↓"),
        (["up"], 126, "↑"),
        (["minus", "-"], 27, "-"),
        (["equal", "="], 24, "="),
        (["comma", ","], 43, ","),
        (["period", "."], 47, "."),
        (["slash", "/"], 44, "/"),
        (["semicolon", ";"], 41, ";"),
        (["quote", "'"], 39, "'"),
        (["backslash", "\\"], 42, "\\"),
        (["grave", "`"], 50, "`"),
        (["leftbracket", "["], 33, "["),
        (["rightbracket", "]"], 30, "]"),
        (["f1"], 122, "F1"), (["f2"], 120, "F2"), (["f3"], 99, "F3"), (["f4"], 118, "F4"),
        (["f5"], 96, "F5"), (["f6"], 97, "F6"), (["f7"], 98, "F7"), (["f8"], 100, "F8"),
        (["f9"], 101, "F9"), (["f10"], 109, "F10"), (["f11"], 103, "F11"), (["f12"], 111, "F12"),
    ]

    private static let characterKeys: [(Character, UInt32)] = [
        ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("h", 4), ("g", 5), ("z", 6), ("x", 7),
        ("c", 8), ("v", 9), ("b", 11), ("q", 12), ("w", 13), ("e", 14), ("r", 15),
        ("y", 16), ("t", 17), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("6", 22),
        ("5", 23), ("9", 25), ("7", 26), ("8", 28), ("0", 29), ("o", 31), ("u", 32),
        ("i", 34), ("p", 35), ("l", 37), ("j", 38), ("k", 40), ("n", 45), ("m", 46),
    ]

    private static let keyCodes: [String: UInt32] = {
        var table: [String: UInt32] = [:]
        for entry in namedKeys {
            for name in entry.names { table[name] = entry.code }
        }
        for (character, code) in characterKeys {
            table[String(character)] = code
        }
        return table
    }()

    /// The first name of each key, for `stringValue`.
    private static let keyNames: [UInt32: String] = {
        var table: [UInt32: String] = [:]
        for entry in namedKeys { table[entry.code] = entry.names[0] }
        for (character, code) in characterKeys { table[code] = String(character) }
        return table
    }()

    private static let functionKeyCodes: Set<UInt32> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    private static let keySymbols: [UInt32: String] = {
        var table: [UInt32: String] = [:]
        for entry in namedKeys { table[entry.code] = entry.symbol }
        for (character, code) in characterKeys { table[code] = String(character).uppercased() }
        return table
    }()
}
