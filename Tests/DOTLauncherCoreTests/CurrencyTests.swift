import Foundation
import Testing
@testable import DOTLauncherCore

private let fixture = """
{"result":"success","provider":"https://www.exchangerate-api.com","time_last_update_unix":1794268951,
 "base_code":"USD","rates":{"USD":1,"IDR":18077,"EUR":0.89342,"SGD":1.2801,"TOP":2.35}}
"""
private let fetched = Date(timeIntervalSince1970: 1_794_300_000)

private func rates() throws -> ExchangeRates {
    try #require(ExchangeRates.decode(Data(fixture.utf8), fetchedAt: fetched))
}

private func currencies(_ conversion: Conversion?) -> (String?, String?) {
    var from: String?, to: String?
    if case .currency(let code)? = conversion?.from { from = code }
    if case .currency(let code)?? = conversion?.to { to = code }
    return (from, to)
}

struct CurrencyTests {
    @Test func `decodes an exchange-rate response`() throws {
        let rates = try rates()
        #expect(rates.base == "USD")
        #expect(rates.rates["IDR"] == 18077)
        #expect(rates.updated == Date(timeIntervalSince1970: 1_794_268_951))
        #expect(rates.fetchedAt == fetched)
        #expect(ExchangeRates.decode(Data(#"{"result":"error","error-type":"unsupported-code"}"#.utf8), fetchedAt: fetched) == nil)
        #expect(ExchangeRates.decode(Data("nonsense".utf8), fetchedAt: fetched) == nil)
    }

    @Test func `converts through the base currency`() throws {
        let rates = try rates()
        #expect(rates.convert(100, from: "USD", to: "IDR") == 1_807_700)
        let euros = try #require(rates.convert(100, from: "EUR", to: "IDR"))
        #expect(abs(euros - 2_023_348.48) < 0.01)
        #expect(rates.convert(1, from: "XYZ", to: "IDR") == nil)
        #expect(rates.knows("SGD"))
        #expect(!rates.knows("XYZ"))
    }

    @Test func `rates refresh after 12 hours and are outdated after a week`() throws {
        let rates = try rates()
        #expect(!rates.needsRefresh(now: fetched.addingTimeInterval(11 * 3600)))
        #expect(rates.needsRefresh(now: fetched.addingTimeInterval(13 * 3600)))
        #expect(!rates.isOutdated(now: rates.updated.addingTimeInterval(6 * 86_400)))
        #expect(rates.isOutdated(now: rates.updated.addingTimeInterval(8 * 86_400)))
    }

    @Test func `cached rates round-trip`() throws {
        let rates = try rates()
        let data = try JSONEncoder().encode(rates)
        #expect(try JSONDecoder().decode(ExchangeRates.self, from: data) == rates)
    }

    @Test func `currency symbols, names and codes parse`() {
        let dollars = Converter.parse("$25")
        #expect(dollars?.amount == 25)
        #expect(currencies(dollars) == ("USD", nil))
        #expect(currencies(Converter.parse("€50 in usd")) == ("EUR", "USD"))
        #expect(currencies(Converter.parse("rp 50000 to sgd")) == ("IDR", "SGD"))
        #expect(Converter.parse("rp 50000 to sgd")?.amount == 50_000)
        #expect(currencies(Converter.parse("100 usd ke idr")) == ("USD", "IDR"))
        #expect(currencies(Converter.parse("100 rupiah to dollar")) == ("IDR", "USD"))
        #expect(currencies(Converter.parse("100 USD to IDR")) == ("USD", "IDR"))
        #expect(currencies(Converter.parse("25usd to idr")) == ("USD", "IDR"))
    }

    @Test func `currency without a target goes to the local currency, or USD when it is local`() throws {
        let dollars = try #require(Converter.parse("$25"))
        #expect(currencies(Converter.resolveCurrencyTarget(dollars, localCurrency: "IDR")) == ("USD", "IDR"))
        let rupiah = try #require(Converter.parse("100 idr"))
        #expect(currencies(Converter.resolveCurrencyTarget(rupiah, localCurrency: "IDR")) == ("IDR", "USD"))
        let local = try #require(Converter.parse("10 usd"))
        #expect(currencies(Converter.resolveCurrencyTarget(local, localCurrency: "USD")) == ("USD", "EUR"))
    }

    @Test func `uncommon codes need a target`() {
        #expect(Converter.parse("10 cat") == nil)
        #expect(Converter.parse("10 top") == nil)
        #expect(currencies(Converter.parse("10 top to idr")) == ("TOP", "IDR"))
        #expect(Converter.parse("10 cat to idr") == nil)
    }

    @Test func `grouped amounts follow the locale`() {
        let enID = Locale(identifier: "en_ID"), enUS = Locale(identifier: "en_US")
        #expect(Converter.parse("rp 50.000 to usd", locale: enID)?.amount == 50_000)
        #expect(Converter.parse("Rp 50.000", locale: enID)?.amount == 50_000)
        #expect(Converter.parse("1.000 usd to idr", locale: enID)?.amount == 1_000)
        #expect(Converter.parse("1.500.000 idr", locale: enID)?.amount == 1_500_000)
        #expect(Converter.parse("1.500.000,75 idr", locale: enID)?.amount == 1_500_000.75)
        #expect(Converter.parse("1,5 kg to g", locale: enID)?.amount == 1.5)
        #expect(Converter.parse("1.5 kg to g", locale: enID)?.amount == 1.5)
        #expect(Converter.parse("1,000 usd to idr", locale: enUS)?.amount == 1_000)
        #expect(Converter.parse("1.5 kg to g", locale: enUS)?.amount == 1.5)
    }

    @Test func `version numbers after a currency code are not conversions`() {
        #expect(Converter.parse("php 8.3") == nil)
        #expect(Converter.parse("PHP 7.4") == nil)
        #expect(Converter.parse("cad 2") == nil)
        #expect(Converter.parse("won 5") == nil)
        #expect(currencies(Converter.parse("us$ 10")) == ("USD", nil))
        #expect(currencies(Converter.parse("€50")) == ("EUR", nil))
        #expect(currencies(Converter.parse("8 php")) == ("PHP", nil))
    }

    @Test func `unit names win over currency codes`() {
        guard case .unit? = Converter.parse("1 cup to ml")?.from else {
            Issue.record("cup should be a unit")
            return
        }
        guard case .unit? = Converter.parse("5 min to s")?.from else {
            Issue.record("min should be a unit")
            return
        }
    }

    @Test func `currency amounts accept shorthand`() {
        let enID = Locale(identifier: "en_ID")
        #expect(Converter.parse("10k usd to idr")?.amount == 10_000)
        #expect(Converter.parse("rp 50rb", locale: enID)?.amount == 50_000)
        #expect(Converter.parse("1,5jt idr", locale: enID)?.amount == 1_500_000)
        #expect(Converter.parse("1 juta rupiah to usd")?.amount == 1_000_000)
        #expect(Converter.parse("1.500jt idr", locale: enID)?.amount == 1_500_000_000)
    }

    @Test func `small currency amounts keep significant digits`() throws {
        let enID = Locale(identifier: "en_ID")
        func shown(_ value: Double) -> String {
            let digits = ConversionFormat.currencyDigits(for: value)
            return ConversionFormat.display(value, maxFractionDigits: digits.maxFractionDigits, significantDigits: digits.significantDigits, locale: enID)
        }
        let rupiah = try #require(try rates().convert(1, from: "IDR", to: "USD"))
        #expect(shown(rupiah) == "0,0000553")
        #expect(shown(0.5) == "0,5")
        #expect(shown(1_807_700) == "1.807.700")
        #expect(shown(0) == "0")
    }
}
