import Foundation

/// Time zones by the names people type: "wib", "jst", "tokyo", "new york".
public enum TimeZoneNames {
    /// "wib" → (Asia/Jakarta, "WIB"); "tokyo" → (Asia/Tokyo, "Tokyo"); nil when unknown.
    public static func zone(for name: String) -> (zone: TimeZone, place: String)? {
        let key = name.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        guard !key.isEmpty else { return nil }
        if let (identifier, place) = fixed[key], let zone = TimeZone(identifier: identifier) { return (zone, place) }
        if (2...5).contains(key.count), key.allSatisfy(\.isLetter), let zone = TimeZone(abbreviation: key.uppercased()) {
            return (zone, key.uppercased())
        }
        if let identifier = cities[key], let zone = TimeZone(identifier: identifier) { return (zone, titleCase(key)) }
        if let (identifier, place) = aliases[key], let zone = TimeZone(identifier: identifier) { return (zone, place) }
        return nil
    }

    /// Names Foundation's abbreviations do not know (or maps oddly: UTC → GMT).
    private static let fixed: [String: (String, String)] = [
        "wib": ("Asia/Jakarta", "WIB"), "wita": ("Asia/Makassar", "WITA"), "wit": ("Asia/Jayapura", "WIT"),
        "aest": ("Australia/Sydney", "AEST"), "utc": ("GMT", "UTC"), "gmt": ("GMT", "GMT"),
    ]

    private static let aliases: [String: (String, String)] = [
        "nyc": ("America/New_York", "New York"), "sf": ("America/Los_Angeles", "San Francisco"),
        "san francisco": ("America/Los_Angeles", "San Francisco"), "bali": ("Asia/Makassar", "Bali"),
        "beijing": ("Asia/Shanghai", "Beijing"), "mumbai": ("Asia/Kolkata", "Mumbai"), "delhi": ("Asia/Kolkata", "Delhi"),
    ]

    /// "new york" → "America/New_York": the last part of every known identifier.
    private static let cities: [String: String] = {
        var table: [String: String] = [:]
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            guard let last = identifier.split(separator: "/").last, identifier.contains("/") else { continue }
            let city = last.replacingOccurrences(of: "_", with: " ").lowercased()
            if table[city] == nil { table[city] = identifier }
        }
        return table
    }()

    private static func titleCase(_ text: String) -> String {
        text.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
