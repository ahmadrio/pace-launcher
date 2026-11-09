import Foundation

/// `settings.json`: loads defaults when missing or unreadable, saves atomically.
public struct SettingsFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> SettingsData {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(SettingsData.self, from: data)
        else { return SettingsData() }
        return settings
    }

    public func save(_ settings: SettingsData) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
