import Foundation

/// `settings.json`: loads defaults when missing or unreadable, saves atomically.
public struct SettingsFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// True while iCloud has only a placeholder (`.settings.json.icloud`).
    /// Saving then would replace the real settings in iCloud with defaults.
    public var isWaitingForDownload: Bool {
        let placeholder = url.deletingLastPathComponent().appending(path: "." + url.lastPathComponent + ".icloud")
        return !FileManager.default.fileExists(atPath: url.path) && FileManager.default.fileExists(atPath: placeholder.path)
    }

    public func load() -> SettingsData {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(SettingsData.self, from: data)
        else { return SettingsData() }
        return settings
    }

    public func save(_ settings: SettingsData) throws {
        guard !isWaitingForDownload else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
