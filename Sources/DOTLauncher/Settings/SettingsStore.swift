import DOTLauncherCore
import Foundation
import Observation

/// The live settings, saved to `settings.json` in the active data folder on
/// every change.
@Observable
final class SettingsStore {
    var data: SettingsData {
        didSet {
            guard data != oldValue, !isLoading else { return }
            save()
        }
    }

    @ObservationIgnored private var file: SettingsFile
    @ObservationIgnored private var isLoading = false

    init() {
        file = SettingsFile(url: AppPaths.settingsFile)
        data = file.load()
        migrateLegacyDefaults()
    }

    /// Re-reads settings.json, e.g. after the data folder moved.
    func reload() {
        file = SettingsFile(url: AppPaths.settingsFile)
        isLoading = true
        data = file.load()
        isLoading = false
    }

    private func save() {
        do {
            try file.save(data)
        } catch {
            Log.app.error("could not save settings: \(String(describing: error), privacy: .public)")
        }
    }

    /// Stage 2 kept the menu bar icon choice in UserDefaults; move it once.
    private func migrateLegacyDefaults() {
        let key = "showMenuBarIcon"
        guard let legacy = UserDefaults.standard.object(forKey: key) as? Bool else { return }
        data.showMenuBarIcon = legacy
        UserDefaults.standard.removeObject(forKey: key)
    }
}
