import Foundation

/// Date and time answers for the launcher: "now + 3 days", "days until
/// 17 aug", "time in tokyo".
public enum DateQuery {
    public enum Result: Equatable, Sendable {
        case date(Date, withTime: Bool)
        /// Until: days into the future; since: days into the past (both ≥ 0).
        case days(Int)
        /// Days between two dates (absolute).
        case difference(Int)
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
            ?? difference(text, now: now, calendar: calendar)
            ?? zoneTime(text, now: now, calendar: calendar)
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
        case .difference(let days):
            switch days {
            case 0: return ("Same day", "0")
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

    // MARK: - Time zones

    /// "time in tokyo", "5pm in london", "9:30am jst to wib", "23.00 wib ke tokyo".
    private static func zoneTime(_ text: String, now: Date, calendar: Calendar) -> Result? {
        if let match = text.wholeMatch(of: /(?:time|jam|waktu) (?:in|di) (.+)/),
           let target = TimeZoneNames.zone(for: String(match.1)) {
            return .time(now, zone: target.zone, place: label(target, at: now),
                         dayChanged: !sameDay(now, calendar.timeZone, target.zone))
        }
        // A time needs minutes or am/pm: "5 in tokyo" is not one.
        guard let match = text.wholeMatch(of: /(\d{1,2})(?:[:.](\d{2}))? ?(am|pm)?(?: (.+?))? (?:in|to|ke) (.+)/),
              match.2 != nil || match.3 != nil,
              var hour = Int(match.1)
        else { return nil }
        let minute = match.2.flatMap { Int($0) } ?? 0
        if let meridiem = match.3 {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (meridiem == "pm" ? 12 : 0)
        }
        guard (0...23).contains(hour), (0...59).contains(minute),
              let target = TimeZoneNames.zone(for: String(match.5))
        else { return nil }
        var source = calendar
        if let name = match.4 {
            guard let zone = TimeZoneNames.zone(for: String(name)) else { return nil }
            source.timeZone = zone.zone
        }
        // That time today, in the source zone.
        var components = source.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        guard let instant = source.date(from: components) else { return nil }
        return .time(instant, zone: target.zone, place: label(target, at: instant),
                     dayChanged: !sameDay(instant, source.timeZone, target.zone))
    }

    /// "New York (UTC−4)" for an abbreviation, so the label matches the
    /// clock shown even in summer time; names with fixed offsets stay as is.
    private static func label(_ target: (zone: TimeZone, place: String, showsOffset: Bool), at date: Date) -> String {
        guard target.showsOffset else { return target.place }
        let seconds = target.zone.secondsFromGMT(for: date)
        guard seconds != 0 else { return target.place + " (UTC)" }
        let sign = seconds < 0 ? "\u{2212}" : "+"
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        let offset = minutes == 0 ? "\(hours)" : "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
        return target.place + " (UTC" + sign + offset + ")"
    }

    private static func sameDay(_ date: Date, _ first: TimeZone, _ second: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = first
        let a = calendar.dateComponents([.year, .month, .day], from: date)
        calendar.timeZone = second
        return a == calendar.dateComponents([.year, .month, .day], from: date)
    }

    // MARK: - Countdowns

    /// "days until 17 aug", "hari sejak 2026-01-01".
    private static func countdown(_ text: String, now: Date, calendar: Calendar) -> Result? {
        guard let match = text.wholeMatch(of: /(?:days?|hari) (until|till|to|since|menuju|sampai|sejak) (.+)/) else { return nil }
        let past = match.1 == "since" || match.1 == "sejak"
        let today = calendar.startOfDay(for: now)
        guard let target = day(String(match.2), today: today, year: past ? .last : .next, calendar: calendar),
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

    // MARK: - Differences

    /// "17 aug - 1 jan", "days between 1 jan and 17 aug": absolute days.
    /// Dates without a year are in the current year.
    private static func difference(_ text: String, now: Date, calendar: Calendar) -> Result? {
        let first: String, second: String
        if let match = text.wholeMatch(of: /(?:days? between|hari antara) (.+) (?:and|dan) (.+)/) {
            (first, second) = (String(match.1), String(match.2))
        } else {
            // Spaces around "-" are required, so "2025-1" stays arithmetic.
            let parts = text.components(separatedBy: " - ")
            guard parts.count == 2 else { return nil }
            (first, second) = (parts[0], parts[1])
        }
        let today = calendar.startOfDay(for: now)
        guard let a = day(first, today: today, year: .current, calendar: calendar),
              let b = day(second, today: today, year: .current, calendar: calendar),
              let days = calendar.dateComponents([.day], from: a, to: b).day
        else { return nil }
        return .difference(abs(days))
    }

    /// Which year a date without one is in.
    private enum YearRule { case next, last, current }

    /// A day written as a base word, "2026-12-25", "17 aug [2027]" or
    /// "aug 17[,] [2027]". Without a year: the next one, the last one, or
    /// this year's, as `year` says. 29 Feb steps to a year that has one.
    private static func day(_ text: String, today: Date, year rule: YearRule, calendar: Calendar) -> Date? {
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
        switch rule {
        case .current:
            return date(in: thisYear)
        case .next:
            return (thisYear...thisYear + 8).lazy.compactMap { date(in: $0) }.first { $0 >= today }
        case .last:
            return stride(from: thisYear, through: thisYear - 8, by: -1).lazy.compactMap { date(in: $0) }.first { $0 <= today }
        }
    }
}
