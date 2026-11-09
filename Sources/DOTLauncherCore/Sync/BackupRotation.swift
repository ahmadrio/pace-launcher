import Foundation

/// Timestamped clipboard backups (`clipboard-yyyyMMdd-HHmm.sqlite`, UTC)
/// in one folder, of which only the newest few are kept.
public enum BackupRotation {
    private static let prefix = "clipboard-"
    private static let suffix = ".sqlite"

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }

    public static func fileName(for date: Date) -> String {
        prefix + formatter().string(from: date) + suffix
    }

    /// Every backup in `folder`, newest first. Other files are ignored.
    public static func backups(in folder: URL) -> [(url: URL, date: Date)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let formatter = formatter()
        return names
            .compactMap { name -> (url: URL, date: Date)? in
                guard name.hasPrefix(prefix), name.hasSuffix(suffix),
                      let date = formatter.date(from: String(name.dropFirst(prefix.count).dropLast(suffix.count)))
                else { return nil }
                return (folder.appending(path: name), date)
            }
            .sorted { $0.date > $1.date }
    }

    /// Deletes all but the newest `keep` backups.
    public static func prune(in folder: URL, keep: Int) throws {
        for backup in backups(in: folder).dropFirst(max(keep, 0)) {
            try FileManager.default.removeItem(at: backup.url)
        }
    }
}
