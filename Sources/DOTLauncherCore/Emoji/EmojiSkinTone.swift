/// One skin tone for every hand and person emoji, as Unicode's five
/// modifiers (Fitzpatrick types) plus the default yellow.
public enum EmojiSkinTone: String, CaseIterable, Codable, Sendable {
    /// Stored as "none" in settings.json.
    case `default` = "none"
    case light, mediumLight, medium, mediumDark, dark

    public var title: String {
        switch self {
        case .default: "Default"
        case .light: "Light"
        case .mediumLight: "Medium-Light"
        case .medium: "Medium"
        case .mediumDark: "Medium-Dark"
        case .dark: "Dark"
        }
    }

    /// The modifier placed after the base emoji; nil for the default.
    public var modifier: String? {
        switch self {
        case .default: nil
        case .light: "\u{1F3FB}"
        case .mediumLight: "\u{1F3FC}"
        case .medium: "\u{1F3FD}"
        case .mediumDark: "\u{1F3FE}"
        case .dark: "\u{1F3FF}"
        }
    }

    /// The following tone, wrapping from Dark back to Default.
    public var next: EmojiSkinTone {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}
