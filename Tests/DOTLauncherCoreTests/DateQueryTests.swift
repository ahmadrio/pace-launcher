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
