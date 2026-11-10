import Foundation

/// Preferences that travel with the user's data (synced with iCloud when
/// enabled). Machine-specific state stays in UserDefaults instead.
public struct SettingsData: Codable, Sendable, Equatable {
    public var showMenuBarIcon = true
    public var theme = ThemeSettings()
    public var autoExpandEnabled = true
    public var autoExpandExcludedBundleIDs: [String] = []
    public var includeClipboardInBackup = true
    /// Global shortcuts by `ShortcutID.rawValue`; "" means none, and a
    /// missing id means the default.
    public var shortcuts: [String: String] = [:]
    /// How long unpinned clips are kept.
    public var clipboardRetention = ClipboardRetention.forever
    /// Saved URLs for the launcher.
    public var quicklinks: [Quicklink] = Quicklink.defaults
    /// Applied to hand and person emoji when they are pasted.
    public var emojiSkinTone = EmojiSkinTone.default
    /// Emoji with a tone of their own, by the catalog's base character.
    public var emojiSkinTones: [String: EmojiSkinTone] = [:]

    public init() {}

    /// The tone to paste `emoji` in: its own, or the default one.
    public func skinTone(for emoji: Emoji) -> EmojiSkinTone {
        emojiSkinTones[emoji.character] ?? emojiSkinTone
    }

    private enum CodingKeys: String, CodingKey {
        case showMenuBarIcon, theme, autoExpandEnabled, autoExpandExcludedBundleIDs, includeClipboardInBackup, shortcuts, clipboardRetention, quicklinks, emojiSkinTone, emojiSkinTones
    }

    /// Missing keys keep their defaults, so older or newer files still load.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SettingsData()
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? defaults.showMenuBarIcon
        theme = try container.decodeIfPresent(ThemeSettings.self, forKey: .theme) ?? defaults.theme
        autoExpandEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoExpandEnabled) ?? defaults.autoExpandEnabled
        autoExpandExcludedBundleIDs = try container.decodeIfPresent([String].self, forKey: .autoExpandExcludedBundleIDs)
            ?? defaults.autoExpandExcludedBundleIDs
        includeClipboardInBackup = try container.decodeIfPresent(Bool.self, forKey: .includeClipboardInBackup)
            ?? defaults.includeClipboardInBackup
        shortcuts = try container.decodeIfPresent([String: String].self, forKey: .shortcuts) ?? defaults.shortcuts
        // An unknown value (from a newer version) keeps the default instead
        // of resetting every setting.
        clipboardRetention = (try? container.decodeIfPresent(ClipboardRetention.self, forKey: .clipboardRetention)) ?? defaults.clipboardRetention
        emojiSkinTone = (try? container.decodeIfPresent(EmojiSkinTone.self, forKey: .emojiSkinTone)) ?? defaults.emojiSkinTone
        // Unknown tones are dropped; anything that is not a map gives none.
        let tones = (try? container.decodeIfPresent([String: String].self, forKey: .emojiSkinTones)) ?? nil
        emojiSkinTones = (tones ?? [:]).compactMapValues(EmojiSkinTone.init(rawValue:))
        // A broken entry is skipped; an unreadable list or a missing key
        // gives the starter quicklinks. Either way the other settings load.
        let links = (try? container.decodeIfPresent([Lossy<Quicklink>].self, forKey: .quicklinks))
            .map { $0.compactMap(\.value) } ?? defaults.quicklinks
        // A copied entry repeats an id: give the copy its own, so Delete and
        // the launcher treat them as two.
        var seen = Set<UUID>()
        quicklinks = links.enumerated().map { index, link in
            var link = link
            var attempt = 0
            while !seen.insert(link.id).inserted {
                attempt += 1
                link.id = Quicklink.derivedID(name: link.name, url: link.url + "#\(index)#\(attempt)")
            }
            return link
        }
    }
}

/// Decodes to nil instead of failing, so one bad array element is skipped.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

