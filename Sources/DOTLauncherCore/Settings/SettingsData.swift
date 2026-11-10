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

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case showMenuBarIcon, theme, autoExpandEnabled, autoExpandExcludedBundleIDs, includeClipboardInBackup, shortcuts, clipboardRetention, quicklinks
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
        // A broken entry is skipped; an unreadable list or a missing key
        // gives the starter quicklinks. Either way the other settings load.
        quicklinks = (try? container.decodeIfPresent([Lossy<Quicklink>].self, forKey: .quicklinks))
            .map { $0.compactMap(\.value) } ?? defaults.quicklinks
    }
}

/// Decodes to nil instead of failing, so one bad array element is skipped.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

