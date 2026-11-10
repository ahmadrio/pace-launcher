import Foundation

/// What a conversion is from or to.
public enum ConversionTarget: Sendable, Equatable {
    case unit(MeasureUnit)
    /// An ISO 4217 code such as "IDR".
    case currency(String)
}

/// "10 km to mi" as data. `to` is nil when the query names no target
/// (only allowed for currencies, e.g. "$25").
public struct Conversion: Sendable, Equatable {
    public let amount: Double
    public let from: ConversionTarget
    public let to: ConversionTarget?

    public init(amount: Double, from: ConversionTarget, to: ConversionTarget?) {
        self.amount = amount
        self.from = from
        self.to = to
    }
}

/// Reads unit and currency conversions typed in the launcher.
public enum Converter {
    /// Words and signs between the amount and the target, tried from the
    /// right so "10 in in cm" converts inches.
    private static let separators = [" to ", " in ", " as ", " ke ", "=", "->", "→"]

    /// nil when the input is not a conversion.
    /// Conversions are short; anything longer (a pasted paragraph sent to
    /// AI with Tab) is skipped without parsing, on every keystroke.
    static let maxLength = 100

    /// nil when the input is not a conversion. `locale` decides how grouped
    /// amounts read: "50.000" is fifty thousand in en_ID.
    public static func parse(_ input: String, locale: Locale = .current) -> Conversion? {
        guard input.utf16.count <= maxLength * 2 else { return nil }
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.count <= maxLength else { return nil }

        for range in separatorRanges(in: text) {
            let left = String(text[..<range.lowerBound])
            let right = String(text[range.upperBound...])
            guard let source = source(in: left, locale: locale), let target = target(named: right) else { continue }
            return Conversion(amount: source.amount, from: source.target, to: target)
        }
        // A currency amount alone ("$25", "100 usd") converts to the
        // local currency; rare codes need a target.
        if let source = source(in: text, locale: locale), case .currency = source.target, CurrencyNames.worksAlone(source.word) {
            return Conversion(amount: source.amount, from: source.target, to: nil)
        }
        return nil
    }

    /// Unit to unit; nil for currencies or units of different kinds.
    public static func convertUnits(_ conversion: Conversion) -> Double? {
        guard case .unit(let from) = conversion.from, case .unit(let to)? = conversion.to,
              from.category == to.category
        else { return nil }
        let value = Measurement(value: conversion.amount, unit: from.dimension).converted(to: to.dimension).value
        return value.isFinite ? value : nil
    }

    /// Fills in the target of a currency amount typed alone: the local
    /// currency, or USD when the amount already is local (EUR for USD).
    public static func resolveCurrencyTarget(_ conversion: Conversion, localCurrency: String?) -> Conversion {
        guard conversion.to == nil, case .currency(let from) = conversion.from else { return conversion }
        let local = localCurrency ?? "USD"
        let to = from != local ? local : (local == "USD" ? "EUR" : "USD")
        return Conversion(amount: conversion.amount, from: conversion.from, to: .currency(to))
    }

    // MARK: - Parsing

    /// Every separator occurrence, rightmost first.
    private static func separatorRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        for separator in separators {
            var searchStart = text.startIndex
            while let range = text.range(of: separator, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                ranges.append(range)
                // Step one character so overlapping " in in " both count.
                searchStart = text.index(after: range.lowerBound)
            }
        }
        return ranges.sorted { $0.lowerBound > $1.lowerBound }
    }

    /// "<amount> <unit>", "<amount> <currency>" or "<currency> <amount>"
    /// on the left of the separator. Units are tried first ("cup").
    static func source(in text: String, locale: Locale) -> (amount: Double, target: ConversionTarget, word: String)? {
        let text = text.trimmingCharacters(in: .whitespaces)
        if let (unit, rest) = MeasureUnit.trailing(in: text), let amount = amount(rest, locale: locale) {
            return (amount, .unit(unit), unit.symbol)
        }
        // "25 usd", "25usd", "100 rupiah", "25$"
        let trailing = text.reversed().prefix { !$0.isNumber && !$0.isWhitespace && $0 != ")" }
        if !trailing.isEmpty {
            let word = String(trailing.reversed())
            if let code = CurrencyNames.code(for: word), let amount = amount(String(text.dropLast(word.count)), locale: locale) {
                return (amount, .currency(code), word)
            }
        }
        // "$25", "rp 50000", "us$ 10", "€50" (signs only: "php 8.3" is a search)
        let leading = text.prefix { !$0.isNumber && !$0.isWhitespace && $0 != "(" && $0 != "-" }
        if !leading.isEmpty, CurrencyNames.isSymbol(String(leading)) {
            let word = String(leading)
            if let code = CurrencyNames.code(for: word), let amount = amount(String(text.dropFirst(word.count)), locale: locale) {
                return (amount, .currency(code), word)
            }
        }
        return nil
    }

    /// An amount: a number grouped the locale's way ("1.500.000,75" in
    /// en_ID), else a plain number or expression where "." and "," both
    /// mean a decimal point ("1,5", "2*5").
    static func amount(_ text: String, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let grouped = groupedNumber(trimmed, locale: locale) { return grouped }
        // "1.500jt" in en_ID is 1.500 juta; the calculator alone would read 1,5.
        if let (number, multiplier) = NumberShorthand.split(trimmed),
           let grouped = groupedNumber(number, locale: locale) {
            return grouped * multiplier
        }
        return Calculator.amount(trimmed)
    }

    private static func groupedNumber(_ text: String, locale: Locale) -> Double? {
        guard let group = locale.groupingSeparator, let decimal = locale.decimalSeparator,
              !group.isEmpty, group != decimal
        else { return nil }
        let pattern = "^\\d{1,3}(" + NSRegularExpression.escapedPattern(for: group) + "\\d{3})+("
            + NSRegularExpression.escapedPattern(for: decimal) + "\\d+)?$"
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return Double(text.replacingOccurrences(of: group, with: "").replacingOccurrences(of: decimal, with: "."))
    }

    /// The single unit or currency on the right of the separator.
    static func target(named text: String) -> ConversionTarget? {
        if let unit = MeasureUnit.named(text) { return .unit(unit) }
        if let code = CurrencyNames.code(for: text) { return .currency(code) }
        return nil
    }
}

/// Number formatting for conversion results.
public enum ConversionFormat {
    /// Grouped for reading: "6.213,71" in en_ID.
    public static func display(_ value: Double, maxFractionDigits: Int?, significantDigits: Int?, locale: Locale) -> String {
        formatter(for: value, maxFractionDigits: maxFractionDigits, significantDigits: significantDigits, locale: locale, grouping: true)
            .string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Without grouping, for pasting into other apps: "6213,71".
    public static func copy(_ value: Double, maxFractionDigits: Int?, significantDigits: Int?, locale: Locale) -> String {
        formatter(for: value, maxFractionDigits: maxFractionDigits, significantDigits: significantDigits, locale: locale, grouping: false)
            .string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formatter(for value: Double, maxFractionDigits: Int?, significantDigits: Int?, locale: Locale, grouping: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = 0
        if let significantDigits {
            // Never round away whole digits: 123456789 stays 123456789.
            let integerDigits = value == 0 ? 1 : Int(floor(log10(abs(value)))) + 1
            if integerDigits >= significantDigits {
                formatter.maximumFractionDigits = 0
            } else {
                formatter.usesSignificantDigits = true
                formatter.minimumSignificantDigits = 1
                formatter.maximumSignificantDigits = significantDigits
            }
        } else {
            formatter.maximumFractionDigits = maxFractionDigits ?? 2
        }
        return formatter
    }
}
