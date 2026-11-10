import Foundation

/// Date and time answers for the launcher: "now + 3 days", "days until
/// 17 aug", "time in tokyo".
public enum DateQuery {
    public enum Result: Equatable, Sendable {
        case date(Date, withTime: Bool)
        /// Until: days into the future; since: days into the past (both ≥ 0).
        case days(Int)
        case time(Date, zone: TimeZone, place: String, dayChanged: Bool)
    }

    /// Nil for anything that is not one of the supported forms.
    public static func evaluate(_ input: String, now: Date, timeZone: TimeZone) -> Result? {
        let text = input.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty, text.count <= 80 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return arithmetic(text, now: now, calendar: calendar)
            ?? countdown(text, now: now, calendar: calendar)
    }

    /// (title, copied text).
    public static func display(_ result: Result, locale: Locale, timeZone: TimeZone) -> (title: String, copy: String) {
        switch result {
        case .days(let days):
            switch days {
            case 0: return ("Today", "0")
            case 1: return ("1 day", "1")
            default: return ("\(days) days", "\(days)")
            }
        case .date(let date, let withTime):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateStyle = .full
            formatter.timeStyle = withTime ? .short : .none
            let title = formatter.string(from: date)
            return (title, title)
        case .time(let date, let zone, let place, let dayChanged):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = zone
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            let time = formatter.string(from: date)
            var title = time + " " + place
            if dayChanged {
                formatter.setLocalizedDateFormatFromTemplate("EEE")
                title += " · " + formatter.string(from: date)
            }
            return (title, time)
        }
    }

    // MARK: - Dates

    /// Day offset from today, or nil for "now" (which keeps the time).
    private static let bases: [(word: String, days: Int?)] = [
        ("hari ini", 0), ("sekarang", nil), ("now", nil), ("today", 0),
        ("tomorrow", 1), ("besok", 1), ("yesterday", -1), ("kemarin", -1),
    ]

    private static func base(_ word: String, now: Date, calendar: Calendar) -> (date: Date, withTime: Bool)? {
        guard let entry = bases.first(where: { $0.word == word }) else { return nil }
        guard let days = entry.days else { return (now, true) }
        guard let date = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) else { return nil }
        return (date, false)
    }

    private static let units: [String: Calendar.Component] = [
        "min": .minute, "mins": .minute, "minute": .minute, "minutes": .minute, "menit": .minute,
        "h": .hour, "hr": .hour, "hrs": .hour, "hour": .hour, "hours": .hour, "jam": .hour,
        "d": .day, "day": .day, "days": .day, "hari": .day,
        "w": .weekOfYear, "wk": .weekOfYear, "wks": .weekOfYear, "week": .weekOfYear, "weeks": .weekOfYear, "minggu": .weekOfYear,
        "mo": .month, "month": .month, "months": .month, "bulan": .month,
        "y": .year, "yr": .year, "yrs": .year, "year": .year, "years": .year, "tahun": .year,
    ]

    /// "today + 1 week + 2 days", "now+90min".
    private static func arithmetic(_ text: String, now: Date, calendar: Calendar) -> Result? {
        guard let entry = bases.first(where: { text.hasPrefix($0.word) }),
              var (date, withTime) = base(entry.word, now: now, calendar: calendar)
        else { return nil }
        var rest = Substring(text.dropFirst(entry.word.count))
        guard !rest.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let term = /^\s*([+-])\s*(\d{1,6})\s*([a-z]+)/
        while !rest.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let match = rest.firstMatch(of: term),
                  let unit = units[String(match.3)], let amount = Int(match.2),
                  let moved = calendar.date(byAdding: unit, value: match.1 == "-" ? -amount : amount, to: date)
            else { return nil }
            date = moved
            if unit == .minute || unit == .hour { withTime = true }
            rest = rest[match.range.upperBound...]
        }
        return .date(date, withTime: withTime)
    }

    // MARK: - Countdowns

    /// "days until 17 aug", "hari sejak 2026-01-01".
    private static func countdown(_ text: String, now: Date, calendar: Calendar) -> Result? {
        guard let match = text.wholeMatch(of: /(?:days?|hari) (until|till|to|since|menuju|sampai|sejak) (.+)/) else { return nil }
        let past = match.1 == "since" || match.1 == "sejak"
        let today = calendar.startOfDay(for: now)
        guard let target = day(String(match.2), today: today, past: past, calendar: calendar),
              let days = calendar.dateComponents([.day], from: today, to: target).day
        else { return nil }
        let count = past ? -days : days
        return count >= 0 ? .days(count) : nil
    }

    private static let months: [String: Int] = {
        let names: [(Int, [String])] = [
            (1, ["jan", "januari", "january"]), (2, ["feb", "februari", "february"]), (3, ["mar", "maret", "march"]),
            (4, ["apr", "april"]), (5, ["mei", "may"]), (6, ["jun", "juni", "june"]), (7, ["jul", "juli", "july"]),
            (8, ["aug", "agu", "agt", "agustus", "august"]), (9, ["sep", "sept", "september"]),
            (10, ["oct", "okt", "oktober", "october"]), (11, ["nov", "november"]), (12, ["dec", "des", "desember", "december"]),
        ]
        var table: [String: Int] = [:]
        for (month, words) in names { for word in words { table[word] = month } }
        return table
    }()

    /// A day written as a base word, "2026-12-25", "17 aug [2027]" or
    /// "aug 17[,] [2027]". Without a year: the next one (or the last one
    /// when counting since).
    private static func day(_ text: String, today: Date, past: Bool, calendar: Calendar) -> Date? {
        if let (date, _) = base(text, now: today, calendar: calendar) { return calendar.startOfDay(for: date) }
        var year: Int?, month: Int?, dayOfMonth: Int?
        if let iso = text.wholeMatch(of: /(\d{4})-(\d{1,2})-(\d{1,2})/) {
            (year, month, dayOfMonth) = (Int(iso.1), Int(iso.2), Int(iso.3))
        } else if let dm = text.wholeMatch(of: /(\d{1,2}) ([a-z]+)\.?(?: (\d{4}))?/) {
            (dayOfMonth, month, year) = (Int(dm.1), months[String(dm.2)], dm.3.flatMap { Int($0) })
        } else if let md = text.wholeMatch(of: /([a-z]+)\.? (\d{1,2}),?(?: (\d{4}))?/) {
            (month, dayOfMonth, year) = (months[String(md.1)], Int(md.2), md.3.flatMap { Int($0) })
        }
        guard let month, let dayOfMonth else { return nil }

        func date(in year: Int) -> Date? {
            let components = DateComponents(year: year, month: month, day: dayOfMonth)
            guard components.isValidDate(in: calendar) else { return nil }
            return calendar.date(from: components)
        }
        if let year { return date(in: year) }
        let thisYear = calendar.component(.year, from: today)
        guard let candidate = date(in: thisYear) else { return nil }
        if past { return candidate <= today ? candidate : date(in: thisYear - 1) }
        return candidate >= today ? candidate : date(in: thisYear + 1)
    }
}
