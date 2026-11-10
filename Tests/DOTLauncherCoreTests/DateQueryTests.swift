import Foundation
import Testing
@testable import DOTLauncherCore

let jakarta = TimeZone(identifier: "Asia/Jakarta")!

/// A wall-clock time in Jakarta.
func wib(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = jakarta
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

let tuesday = wib(2026, 11, 10, 14, 53)

func evaluate(_ input: String, now: Date = tuesday) -> DateQuery.Result? {
    DateQuery.evaluate(input, now: now, timeZone: jakarta)
}

struct DateQueryTests {
    @Test func `dates move by units`() {
        #expect(evaluate("now + 3 days") == .date(wib(2026, 11, 13, 14, 53), withTime: true))
        #expect(evaluate("today + 2 weeks") == .date(wib(2026, 11, 24), withTime: false))
        #expect(evaluate("tomorrow - 1 day") == .date(wib(2026, 11, 10), withTime: false))
        #expect(evaluate("besok + 1 bulan") == .date(wib(2026, 12, 11), withTime: false))
        #expect(evaluate("today + 1 week + 2 days") == .date(wib(2026, 11, 19), withTime: false))
        #expect(evaluate("today + 3 hours") == .date(wib(2026, 11, 10, 3), withTime: true))
        #expect(evaluate("hari ini + 2 hari") == .date(wib(2026, 11, 12), withTime: false))
        #expect(evaluate("Now+90min") == .date(wib(2026, 11, 10, 16, 23), withTime: true))
    }

    @Test func `month steps clamp to the month's end`() {
        #expect(evaluate("today + 1 month", now: wib(2027, 1, 31, 10)) == .date(wib(2027, 2, 28), withTime: false))
    }

    @Test func `countdowns pick the next or last occurrence`() {
        #expect(evaluate("days until 17 aug") == .days(280))
        #expect(evaluate("days until 25 dec") == .days(45))
        #expect(evaluate("days since 17 agustus") == .days(85))
        #expect(evaluate("hari menuju 2026-12-25") == .days(45))
        #expect(evaluate("days until 10 nov") == .days(0))
        #expect(evaluate("days until aug 17, 2027") == .days(280))
        #expect(evaluate("days since today") == .days(0))
    }

    @Test func `plain words are not date queries`() {
        for input in ["now", "today", "time", "tokyo", "now + 3", "today + 3 bananas", "now plus 3 days", "days until",
                      "days until bananas", "days until 31 feb", "10 in in cm", "5 min to s", "2+2"] {
            #expect(evaluate(input) == nil, "\(input)")
        }
    }

    @Test func `results read naturally`() {
        let enUS = Locale(identifier: "en_US")
        #expect(DateQuery.display(.days(280), locale: enUS, timeZone: jakarta) == ("280 days", "280"))
        #expect(DateQuery.display(.days(1), locale: enUS, timeZone: jakarta) == ("1 day", "1"))
        #expect(DateQuery.display(.days(0), locale: enUS, timeZone: jakarta) == ("Today", "0"))
        let date = DateQuery.display(.date(wib(2026, 11, 13), withTime: false), locale: enUS, timeZone: jakarta)
        #expect(date.title.contains("November 13, 2026"))
        #expect(date.copy == date.title)
    }
}

struct TimeZoneQueryTests {
    @Test func `zones by name`() {
        let expected: [(String, String)] = [
            ("wib", "Asia/Jakarta"), ("WITA", "Asia/Makassar"), ("wit", "Asia/Jayapura"), ("jst", "Asia/Tokyo"),
            ("pst", "America/Los_Angeles"), ("aest", "Australia/Sydney"), ("utc", "GMT"), ("tokyo", "Asia/Tokyo"),
            ("New York", "America/New_York"), ("nyc", "America/New_York"), ("bali", "Asia/Makassar"),
        ]
        for (name, identifier) in expected {
            #expect(TimeZoneNames.zone(for: name)?.zone.identifier == identifier, "\(name)")
        }
        #expect(TimeZoneNames.zone(for: "atlantis") == nil)
        #expect(TimeZoneNames.zone(for: "new york")?.place == "New York")
        #expect(TimeZoneNames.zone(for: "wib")?.place == "WIB")
    }

    @Test func `time in a place`() {
        #expect(evaluate("time in tokyo") == .time(tuesday, zone: TimeZone(identifier: "Asia/Tokyo")!, place: "Tokyo", dayChanged: false))
        #expect(evaluate("jam di tokyo") == .time(tuesday, zone: TimeZone(identifier: "Asia/Tokyo")!, place: "Tokyo", dayChanged: false))
    }

    @Test func `converted times can cross midnight`() {
        #expect(evaluate("5pm in london") == .time(wib(2026, 11, 10, 17), zone: TimeZone(identifier: "Europe/London")!, place: "London", dayChanged: false))
        #expect(evaluate("9:30am jst to wib") == .time(wib(2026, 11, 10, 7, 30), zone: jakarta, place: "WIB", dayChanged: false))
        #expect(evaluate("23.00 wib in tokyo") == .time(wib(2026, 11, 10, 23), zone: TimeZone(identifier: "Asia/Tokyo")!, place: "Tokyo", dayChanged: true))
        guard case .time(_, _, let place, _)? = evaluate("17:00 ke new york") else {
            Issue.record("expected a time")
            return
        }
        #expect(place == "New York")
    }

    @Test func `ambiguous times are not converted`() {
        for input in ["5 in tokyo", "13pm in tokyo", "25:00 in tokyo", "time in atlantis", "5pm in"] {
            #expect(evaluate(input) == nil, "\(input)")
        }
    }

    @Test func `converted times show the day when it changes`() {
        let result = DateQuery.display(.time(wib(2026, 11, 10, 23), zone: TimeZone(identifier: "Asia/Tokyo")!, place: "Tokyo", dayChanged: true),
                                       locale: Locale(identifier: "en_US"), timeZone: jakarta)
        #expect(result.title.contains("Tokyo"))
        #expect(result.title.contains(" · "))
        #expect(!result.copy.contains("Tokyo"))
        #expect(result.copy.contains("1:00"))
    }
}

struct ZoneAbbreviationTests {
    private func place(_ input: String, now: Date = tuesday) -> String? {
        guard case .time(_, _, let place, _)? = evaluate(input, now: now) else { return nil }
        return place
    }

    @Test func `abbreviations follow the city's clock`() {
        #expect(place("time in est", now: wib(2026, 7, 10, 14, 53)) == "New York (UTC\u{2212}4)")
        #expect(place("time in est") == "New York (UTC\u{2212}5)")
        #expect(place("time in aest") == "Sydney (UTC+11)")
        #expect(place("5pm in ist") == "Kolkata (UTC+5:30)")
        #expect(place("9:30am jst to wib") == "WIB")
        #expect(place("time in utc") == "UTC")
    }

    @Test func `ordinary words are not zones`() {
        for word in ["eat", "cat", "art", "wet", "may"] {
            #expect(TimeZoneNames.zone(for: word) == nil, "\(word)")
        }
        #expect(evaluate("5pm to eat") == nil)
    }

    @Test func `indian cities`() {
        for name in ["kolkata", "bengaluru", "india"] {
            #expect(TimeZoneNames.zone(for: name)?.zone.secondsFromGMT(for: tuesday) == 19_800, "\(name)")
        }
    }
}

struct DateDifferenceTests {
    @Test func `differences between two dates`() {
        #expect(evaluate("17 aug - 1 jan") == .difference(228))
        #expect(evaluate("1 jan - 17 aug") == .difference(228))
        #expect(evaluate("2026-12-25 - today") == .difference(45))
        #expect(evaluate("17 aug 2027 - 17 aug 2026") == .difference(365))
        #expect(evaluate("days between 1 jan and 17 aug") == .difference(228))
        #expect(evaluate("hari antara 1 januari dan 17 agustus") == .difference(228))
        #expect(evaluate("today - today") == .difference(0))
        #expect(DateQuery.display(.difference(0), locale: Locale(identifier: "en_US"), timeZone: jakarta) == ("Same day", "0"))
        #expect(DateQuery.display(.difference(228), locale: Locale(identifier: "en_US"), timeZone: jakarta) == ("228 days", "228"))
    }

    @Test func `differences need two dates`() {
        for input in ["25 - 1", "2025-1", "17 aug - bananas", "17 aug -1 jan", "days between 1 jan"] {
            #expect(evaluate(input) == nil, "\(input)")
        }
        #expect(evaluate("today - 1 day") == .date(wib(2026, 11, 9), withTime: false))
    }

    @Test func `29 february without a year`() {
        #expect(evaluate("days until 29 feb") == .days(476))
        #expect(evaluate("days since 29 feb") == .days(985))
    }
}

struct ZoneCoverageTests {
    @Test func `abbreviations that used to work still resolve`() {
        let expected: [(String, String)] = [
            ("pkt", "Asia/Karachi"), ("trt", "Europe/Istanbul"), ("brt", "America/Sao_Paulo"), ("irst", "Asia/Tehran"),
            ("bdt", "Asia/Dhaka"), ("akdt", "America/Anchorage"), ("adt", "America/Halifax"), ("nst", "America/St_Johns"),
            ("ndt", "America/St_Johns"), ("clt", "America/Santiago"), ("nzt", "Pacific/Auckland"),
        ]
        for (name, identifier) in expected {
            #expect(TimeZoneNames.zone(for: name)?.zone.identifier == identifier, "\(name)")
        }
    }

    @Test func `review focus examples`() {
        #expect(evaluate("2026-12-25 - 2026-01-01") == .difference(358))
        #expect(evaluate("2026-12-25 - 1") == nil)
        guard case .time(_, _, let place, _)? = evaluate("time in bst") else {
            Issue.record("expected a time")
            return
        }
        #expect(place == "London (UTC)")
    }
}

struct CityWordTests {
    @Test func `words after a time are not cities`() {
        for input in ["5pm to wake", "5pm in center", "9:00 ke phoenix"] {
            #expect(evaluate(input) == nil, "\(input)")
        }
        guard case .time(_, let zone, _, _)? = evaluate("time in phoenix") else {
            Issue.record("expected a time")
            return
        }
        #expect(zone.identifier == "America/Phoenix")
    }
}

