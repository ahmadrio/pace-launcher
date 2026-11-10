/// Why a recorded shortcut cannot be used.
public enum ShortcutProblem: Equatable, Sendable {
    case required
    case needsModifier
    case unknownKey
    case usedBy(ShortcutID)
    case usedByMacOS
    case reservedByApps

    public var message: String {
        switch self {
        case .required: "Open DOT Launcher needs a shortcut."
        case .needsModifier: "Add ⌘, ⌃ or ⌥."
        case .unknownKey: "This key can't be used."
        case .usedBy(let other): "Already used by \(other.title)."
        case .usedByMacOS: "Used by macOS."
        case .reservedByApps: "Apps use this shortcut (copy, paste, …)."
        }
    }
}

/// The rules for the user's global shortcuts (settings.json `shortcuts`).
public enum Shortcuts {
    /// The combo each shortcut uses: the saved one, none when saved as "",
    /// or the default when nothing (or nothing readable) is saved. The
    /// launcher always gets one.
    public static func resolve(_ saved: [String: String]) -> [ShortcutID: KeyCombo] {
        var result: [ShortcutID: KeyCombo] = [:]
        for id in ShortcutID.allCases {
            if let string = saved[id.rawValue] {
                if let combo = KeyCombo(string) {
                    result[id] = combo
                    continue
                }
                if string.isEmpty, !id.isRequired { continue }
            }
            result[id] = id.defaultCombo
        }
        return result
    }

    /// Nil when `combo` may be used for `id`; nil `combo` means "none".
    public static func validate(_ combo: KeyCombo?, for id: ShortcutID, current: [ShortcutID: KeyCombo], system: [KeyCombo]) -> ShortcutProblem? {
        guard let combo else { return id.isRequired ? .required : nil }
        if !combo.isKnownKey { return .unknownKey }
        let strong = KeyCombo.command | KeyCombo.control | KeyCombo.option
        if combo.carbonModifiers & strong == 0, !combo.isFunctionKey { return .needsModifier }
        if isReservedByApps(combo) { return .reservedByApps }
        if let other = ShortcutID.allCases.first(where: { $0 != id && current[$0] == combo }) { return .usedBy(other) }
        if combo.conflicts(with: system) { return .usedByMacOS }
        return nil
    }

    /// Standard shortcuts every app relies on. A global hotkey wins over
    /// app menus, so taking ⌘V would break paste everywhere.
    private static let reservedCommandKeys: Set<String> = [
        "cmd+c", "cmd+v", "cmd+x", "cmd+z", "cmd+a", "cmd+s", "cmd+q", "cmd+w", "cmd+n", "cmd+t", "cmd+o",
        "cmd+p", "cmd+f", "cmd+h", "cmd+m", "cmd+tab", "cmd+space", "cmd+comma",
        "shift+cmd+z", "shift+cmd+s",
    ]

    public static func isReservedByApps(_ combo: KeyCombo) -> Bool {
        reservedCommandKeys.contains(combo.stringValue)
    }

    /// How to move from the registered hotkeys to the desired ones: every
    /// changed or removed id is released first, so swapping two combos never
    /// collides with a combo that is still held.
    public static func registrationPlan(registered: [ShortcutID: KeyCombo], desired: [ShortcutID: KeyCombo]) -> (release: [ShortcutID], register: [ShortcutID]) {
        let release = ShortcutID.allCases.filter { id in
            guard let held = registered[id] else { return false }
            return desired[id] != held
        }
        let register = ShortcutID.allCases.filter { id in
            guard let wanted = desired[id] else { return false }
            return registered[id] != wanted
        }
        return (release, register)
    }

    /// Default combos copy Maccy's and Rectangle's shortcuts, so they step
    /// aside while those apps run. A combo the user picked never does.
    public static func followsOtherAppHabit(_ id: ShortcutID, _ combo: KeyCombo) -> Bool {
        id != .launcher && combo == id.defaultCombo
    }

    /// The settings map after choosing `combo` for `id`: the default is not
    /// stored, and "none" is stored as "".
    public static func saved(_ combo: KeyCombo?, for id: ShortcutID, in saved: [String: String]) -> [String: String] {
        var result = saved
        if combo == id.defaultCombo {
            result.removeValue(forKey: id.rawValue)
        } else {
            result[id.rawValue] = combo?.stringValue ?? ""
        }
        return result
    }
}
