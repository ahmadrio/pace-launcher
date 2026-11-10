/// Why a recorded shortcut cannot be used.
public enum ShortcutProblem: Equatable, Sendable {
    case required
    case needsModifier
    case unknownKey
    case usedBy(ShortcutID)
    case usedByMacOS

    public var message: String {
        switch self {
        case .required: "Open DOT Launcher needs a shortcut."
        case .needsModifier: "Add ⌘, ⌃ or ⌥."
        case .unknownKey: "This key can't be used."
        case .usedBy(let other): "Already used by \(other.title)."
        case .usedByMacOS: "Used by macOS."
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
        if let other = ShortcutID.allCases.first(where: { $0 != id && current[$0] == combo }) { return .usedBy(other) }
        if combo.conflicts(with: system) { return .usedByMacOS }
        return nil
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
