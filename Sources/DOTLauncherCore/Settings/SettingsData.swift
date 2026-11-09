import Foundation

/// Preferences that travel with the user's data (synced with iCloud when
/// enabled). Machine-specific state stays in UserDefaults instead.
public struct SettingsData: Codable, Sendable, Equatable {
    public var showMenuBarIcon = true
    public var theme = ThemeSettings()
    public var autoExpandEnabled = true
    public var autoExpandExcludedBundleIDs: [String] = []
    public var includeClipboardInBackup = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case showMenuBarIcon, theme, autoExpandEnabled, autoExpandExcludedBundleIDs, includeClipboardInBackup
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
    }
}

