import Foundation
import Testing
@testable import DOTLauncherCore

/// Converts `input` unit to unit, or nil.
private func convert(_ input: String) -> Double? {
    Converter.parse(input).flatMap(Converter.convertUnits)
}

private func near(_ value: Double?, _ expected: Double, tolerance: Double = 0.0001) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance * max(1, abs(expected))
}

private let enID = Locale(identifier: "en_ID")
private let enUS = Locale(identifier: "en_US")

struct ConverterTests {
    @Test func `converts length, mass and data`() {
        #expect(near(convert("10 km to mi"), 6.21371))
        #expect(near(convert("1 lb in kg"), 0.453592))
        #expect(near(convert("1 GiB to MB"), 1073.741824))
        #expect(near(convert("8 b to B"), 1))
        #expect(convert("2*5 km to m") == 10_000)
        #expect(near(convert("10km to mi"), 6.21371))
    }

    @Test func `converts temperature with offsets`() {
        #expect(near(convert("100 c to f"), 212))
        #expect(near(convert("32 °F to C"), 0))
        #expect(near(convert("0 k to c"), -273.15))
    }

    @Test func `ambiguous words resolve to units`() {
        #expect(near(convert("10 in in cm"), 25.4))
        #expect(near(convert("1 m to ft"), 3.28084))
        #expect(near(convert("1 cup to ml"), 236.588, tolerance: 0.001))
        #expect(convert("5 min to s") == 300)
    }

    @Test func `long names and plurals are accepted`() {
        #expect(near(convert("3 meters to feet"), 9.84252))
        #expect(near(convert("2 pounds = kg"), 0.907185))
        #expect(convert("1 kilometer ke m") == 1000)
        #expect(convert("1 hour -> minutes") == 60)
    }

    @Test func `speed and area units`() {
        #expect(near(convert("100 km/h to mph"), 62.1371))
        #expect(near(convert("1 ha to m2"), 10_000))
        #expect(near(convert("1 km² to ha"), 100))
    }

    @Test func `different categories give no result`() {
        #expect(Converter.parse("10 km to kg") != nil)
        #expect(convert("10 km to kg") == nil)
    }

    @Test func `plain text and calculations are not conversions`() {
        #expect(Converter.parse("2+2") == nil)
        #expect(Converter.parse("hello world") == nil)
        #expect(Converter.parse("km to mi") == nil)
        #expect(Converter.parse("open notes") == nil)
        #expect(Converter.parse("10 km") == nil)
    }

    @Test func `long pasted text is rejected quickly`() {
        let paragraph = String(repeating: "Please explain how to move 10 km in an hour to someone ", count: 360) + "10 km to mi"
        let started = Date.now
        #expect(Converter.parse(paragraph) == nil)
        #expect(Date.now.timeIntervalSince(started) < 0.1)
    }

    @Test func `parse reports the units`() throws {
        let conversion = try #require(Converter.parse("10 km to mi"))
        #expect(conversion.amount == 10)
        guard case .unit(let from) = conversion.from, case .unit(let to)? = conversion.to else {
            Issue.record("expected units")
            return
        }
        #expect(from.symbol == "km")
        #expect(to.symbol == "mi")
        #expect(from.category == .length)
    }

    @Test func `display uses significant digits and locale grouping`() {
        #expect(ConversionFormat.display(6213.7119, maxFractionDigits: nil, significantDigits: 6, locale: enID) == "6.213,71")
        #expect(ConversionFormat.display(6.2137119, maxFractionDigits: nil, significantDigits: 6, locale: enID) == "6,21371")
        #expect(ConversionFormat.display(1_807_700, maxFractionDigits: 2, significantDigits: nil, locale: enID) == "1.807.700")
        #expect(ConversionFormat.display(5.534, maxFractionDigits: 2, significantDigits: nil, locale: enUS) == "5.53")
    }

    @Test func `copied value has no grouping`() {
        #expect(ConversionFormat.copy(6213.7119, maxFractionDigits: nil, significantDigits: 6, locale: enID) == "6213,71")
        #expect(ConversionFormat.copy(1_807_700, maxFractionDigits: 2, significantDigits: nil, locale: enUS) == "1807700")
    }

    @Test func `units win over shorthand`() {
        #expect(near(convert("10k to c"), -263.15))
        #expect(near(convert("1 m to ft"), 3.28084))
        #expect(near(convert("10kg to lb"), 22.0462))
        #expect(near(convert("1k km to mi"), 621.371))
        #expect(Converter.parse("1jt to kg") == nil)
    }

    @Test func `bits use a capital prefix and a small b`() {
        #expect(near(convert("1 Mb to MB"), 0.125))
        #expect(near(convert("1 Gb to Mb"), 1000))
        #expect(near(convert("100 Mbit to MB"), 12.5))
        #expect(convert("1 mb to kb") == 1000)
        #expect(convert("8 b to B") == 1)
        #expect(MeasureUnit.named("Mb")?.symbol == "Mbit")
        #expect(MeasureUnit.named("mb")?.symbol == "MB")
    }
}
