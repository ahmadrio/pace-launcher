import Foundation

/// User preferences kept in UserDefaults.
enum AppSettings {
    private static let showMenuBarIconKey = "showMenuBarIcon"

    static var showMenuBarIcon: Bool {
        get { UserDefaults.standard.object(forKey: showMenuBarIconKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showMenuBarIconKey) }
    }
}
