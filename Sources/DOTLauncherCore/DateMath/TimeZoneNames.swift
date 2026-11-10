import Foundation

/// Time zones by the names people type: "wib", "jst", "tokyo", "new york".
public enum TimeZoneNames {
    /// "wib" → (Asia/Jakarta, "WIB"); "tokyo" → (Asia/Tokyo, "Tokyo");
    /// "est" → (America/New_York, "New York", showsOffset). Nil when unknown.
    /// `showsOffset`: an abbreviation stands for its city's clock (summer
    /// time included), so the label adds the real offset.
    public static func zone(for name: String) -> (zone: TimeZone, place: String, showsOffset: Bool)? {
        let key = name.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        guard !key.isEmpty else { return nil }
        if let (identifier, place) = fixed[key], let zone = TimeZone(identifier: identifier) { return (zone, place, false) }
        if let (identifier, city) = abbreviations[key], let zone = TimeZone(identifier: identifier) { return (zone, city, true) }
        if let identifier = cities[key], let zone = TimeZone(identifier: identifier) { return (zone, titleCase(key), false) }
        if let (identifier, place) = aliases[key], let zone = TimeZone(identifier: identifier) { return (zone, place, false) }
        return nil
    }

    /// Offsets that never change, shown by name. Checked first: Foundation
    /// maps WIT to Jakarta (it is Jayapura) and UTC to GMT.
    private static let fixed: [String: (String, String)] = [
        "wib": ("Asia/Jakarta", "WIB"), "wita": ("Asia/Makassar", "WITA"), "wit": ("Asia/Jayapura", "WIT"),
        "utc": ("GMT", "UTC"), "gmt": ("GMT", "GMT"),
    ]

    /// The abbreviations people write, each standing for one city's clock.
    /// A fixed list: Foundation also knows words such as EAT, CAT and ART.
    private static let abbreviations: [String: (String, String)] = {
        let groups: [([String], String, String)] = [
            (["pt", "pst", "pdt"], "America/Los_Angeles", "Los Angeles"), (["mt", "mst", "mdt"], "America/Denver", "Denver"),
            (["ct", "cst", "cdt"], "America/Chicago", "Chicago"), (["et", "est", "edt"], "America/New_York", "New York"),
            (["akst"], "America/Anchorage", "Anchorage"), (["hst"], "Pacific/Honolulu", "Honolulu"),
            (["bst"], "Europe/London", "London"), (["cet", "cest"], "Europe/Paris", "Paris"),
            (["eet", "eest"], "Europe/Athens", "Athens"), (["msk"], "Europe/Moscow", "Moscow"),
            (["ist"], "Asia/Kolkata", "Kolkata"), (["gst"], "Asia/Dubai", "Dubai"), (["ict"], "Asia/Bangkok", "Bangkok"),
            (["pht"], "Asia/Manila", "Manila"), (["myt"], "Asia/Kuala_Lumpur", "Kuala Lumpur"),
            (["sgt"], "Asia/Singapore", "Singapore"), (["hkt"], "Asia/Hong_Kong", "Hong Kong"),
            (["jst"], "Asia/Tokyo", "Tokyo"), (["kst"], "Asia/Seoul", "Seoul"),
            (["aest", "aedt"], "Australia/Sydney", "Sydney"), (["acst", "acdt"], "Australia/Adelaide", "Adelaide"),
            (["awst"], "Australia/Perth", "Perth"), (["nzst", "nzdt"], "Pacific/Auckland", "Auckland"),
        ]
        var table: [String: (String, String)] = [:]
        for (names, identifier, city) in groups { for name in names { table[name] = (identifier, city) } }
        return table
    }()

    private static let aliases: [String: (String, String)] = [
        "nyc": ("America/New_York", "New York"), "sf": ("America/Los_Angeles", "San Francisco"),
        "san francisco": ("America/Los_Angeles", "San Francisco"), "bali": ("Asia/Makassar", "Bali"),
        "beijing": ("Asia/Shanghai", "Beijing"), "mumbai": ("Asia/Kolkata", "Mumbai"), "delhi": ("Asia/Kolkata", "Delhi"),
        // macOS lists India's zone under its old name, Asia/Calcutta.
        "kolkata": ("Asia/Kolkata", "Kolkata"), "bengaluru": ("Asia/Kolkata", "Bengaluru"),
        "bangalore": ("Asia/Kolkata", "Bangalore"), "india": ("Asia/Kolkata", "India"),
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
