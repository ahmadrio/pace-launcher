import Foundation

/// A unit the calculator converts, with the words people type for it.
public struct MeasureUnit: Sendable, Hashable {
    public enum Category: Sendable, Hashable { case length, mass, temperature, volume, area, speed, duration, data }

    /// The short form shown in results ("km", "°C", "GiB").
    public let symbol: String
    public let category: Category

    /// Every known unit with its aliases. Aliases are matched without case,
    /// except the ones in `exactAliases` (bits "b" vs bytes "B").
    static let all: [(unit: MeasureUnit, aliases: [String], exactAliases: [String])] = [
        // Length
        (MeasureUnit(symbol: "mm", category: .length), ["mm", "millimeter", "millimeters", "millimetre", "millimetres"], []),
        (MeasureUnit(symbol: "cm", category: .length), ["cm", "centimeter", "centimeters", "centimetre", "centimetres"], []),
        (MeasureUnit(symbol: "m", category: .length), ["m", "meter", "meters", "metre", "metres"], []),
        (MeasureUnit(symbol: "km", category: .length), ["km", "kilometer", "kilometers", "kilometre", "kilometres"], []),
        (MeasureUnit(symbol: "in", category: .length), ["in", "inch", "inches", "\""], []),
        (MeasureUnit(symbol: "ft", category: .length), ["ft", "foot", "feet", "'"], []),
        (MeasureUnit(symbol: "yd", category: .length), ["yd", "yard", "yards"], []),
        (MeasureUnit(symbol: "mi", category: .length), ["mi", "mile", "miles"], []),
        (MeasureUnit(symbol: "nmi", category: .length), ["nmi", "nautical mile", "nautical miles"], []),
        // Mass
        (MeasureUnit(symbol: "mg", category: .mass), ["mg", "milligram", "milligrams"], []),
        (MeasureUnit(symbol: "g", category: .mass), ["g", "gram", "grams", "gramme", "grammes"], []),
        (MeasureUnit(symbol: "kg", category: .mass), ["kg", "kilogram", "kilograms", "kilo", "kilos"], []),
        (MeasureUnit(symbol: "t", category: .mass), ["t", "ton", "tons", "tonne", "tonnes"], []),
        (MeasureUnit(symbol: "oz", category: .mass), ["oz", "ounce", "ounces"], []),
        (MeasureUnit(symbol: "lb", category: .mass), ["lb", "lbs", "pound", "pounds"], []),
        (MeasureUnit(symbol: "st", category: .mass), ["st", "stone", "stones"], []),
        // Temperature
        (MeasureUnit(symbol: "°C", category: .temperature), ["c", "°c", "º c", "° c", "degc", "celsius"], []),
        (MeasureUnit(symbol: "°F", category: .temperature), ["f", "°f", "° f", "degf", "fahrenheit"], []),
        (MeasureUnit(symbol: "K", category: .temperature), ["k", "kelvin"], []),
        // Volume
        (MeasureUnit(symbol: "ml", category: .volume), ["ml", "milliliter", "milliliters", "millilitre", "millilitres"], []),
        (MeasureUnit(symbol: "l", category: .volume), ["l", "liter", "liters", "litre", "litres"], []),
        (MeasureUnit(symbol: "tsp", category: .volume), ["tsp", "teaspoon", "teaspoons"], []),
        (MeasureUnit(symbol: "tbsp", category: .volume), ["tbsp", "tablespoon", "tablespoons"], []),
        (MeasureUnit(symbol: "cup", category: .volume), ["cup", "cups"], []),
        (MeasureUnit(symbol: "fl oz", category: .volume), ["floz", "fl oz", "fluid ounce", "fluid ounces"], []),
        (MeasureUnit(symbol: "pt", category: .volume), ["pt", "pint", "pints"], []),
        (MeasureUnit(symbol: "qt", category: .volume), ["qt", "quart", "quarts"], []),
        (MeasureUnit(symbol: "gal", category: .volume), ["gal", "gallon", "gallons"], []),
        // Area
        (MeasureUnit(symbol: "mm²", category: .area), ["mm²", "mm2", "sq mm"], []),
        (MeasureUnit(symbol: "cm²", category: .area), ["cm²", "cm2", "sq cm"], []),
        (MeasureUnit(symbol: "m²", category: .area), ["m²", "m2", "sqm", "sq m", "square meter", "square meters", "square metre", "square metres"], []),
        (MeasureUnit(symbol: "km²", category: .area), ["km²", "km2", "sq km", "square kilometer", "square kilometers"], []),
        (MeasureUnit(symbol: "ha", category: .area), ["ha", "hectare", "hectares"], []),
        (MeasureUnit(symbol: "acre", category: .area), ["acre", "acres", "ac"], []),
        (MeasureUnit(symbol: "ft²", category: .area), ["ft²", "ft2", "sq ft", "sqft", "square foot", "square feet"], []),
        (MeasureUnit(symbol: "in²", category: .area), ["in²", "in2", "sq in", "square inch", "square inches"], []),
        // Speed
        (MeasureUnit(symbol: "m/s", category: .speed), ["m/s", "mps"], []),
        (MeasureUnit(symbol: "km/h", category: .speed), ["km/h", "kmh", "kph", "kmph"], []),
        (MeasureUnit(symbol: "mph", category: .speed), ["mph"], []),
        (MeasureUnit(symbol: "kn", category: .speed), ["kn", "kt", "knot", "knots"], []),
        // Duration
        (MeasureUnit(symbol: "ms", category: .duration), ["ms", "millisecond", "milliseconds"], []),
        (MeasureUnit(symbol: "s", category: .duration), ["s", "sec", "secs", "second", "seconds"], []),
        (MeasureUnit(symbol: "min", category: .duration), ["min", "mins", "minute", "minutes"], []),
        (MeasureUnit(symbol: "h", category: .duration), ["h", "hr", "hrs", "hour", "hours"], []),
        (MeasureUnit(symbol: "d", category: .duration), ["d", "day", "days"], []),
        (MeasureUnit(symbol: "wk", category: .duration), ["wk", "week", "weeks"], []),
        // Data (decimal and binary; "b" is a bit, "B" a byte)
        (MeasureUnit(symbol: "bit", category: .data), ["bit", "bits"], ["b"]),
        (MeasureUnit(symbol: "B", category: .data), ["byte", "bytes"], ["B"]),
        (MeasureUnit(symbol: "KB", category: .data), ["kb", "kilobyte", "kilobytes"], []),
        (MeasureUnit(symbol: "MB", category: .data), ["mb", "megabyte", "megabytes"], []),
        (MeasureUnit(symbol: "GB", category: .data), ["gb", "gigabyte", "gigabytes"], []),
        (MeasureUnit(symbol: "TB", category: .data), ["tb", "terabyte", "terabytes"], []),
        // Bits: a capital prefix and a small b ("Mb"); all lowercase ("mb") stays bytes.
        (MeasureUnit(symbol: "kbit", category: .data), ["kbit", "kilobit", "kilobits"], ["Kb"]),
        (MeasureUnit(symbol: "Mbit", category: .data), ["mbit", "megabit", "megabits"], ["Mb"]),
        (MeasureUnit(symbol: "Gbit", category: .data), ["gbit", "gigabit", "gigabits"], ["Gb"]),
        (MeasureUnit(symbol: "Tbit", category: .data), ["tbit", "terabit", "terabits"], ["Tb"]),
        (MeasureUnit(symbol: "KiB", category: .data), ["kib", "kibibyte", "kibibytes"], []),
        (MeasureUnit(symbol: "MiB", category: .data), ["mib", "mebibyte", "mebibytes"], []),
        (MeasureUnit(symbol: "GiB", category: .data), ["gib", "gibibyte", "gibibytes"], []),
        (MeasureUnit(symbol: "TiB", category: .data), ["tib", "tebibyte", "tebibytes"], []),
    ]

    /// (alias, unit, exact) pairs, longest alias first, so "km" wins over "m";
    /// exact aliases before case-insensitive ones of the same length ("Mb" before "mb").
    static let aliasTable: [(alias: String, unit: MeasureUnit, exact: Bool)] = {
        var table: [(alias: String, unit: MeasureUnit, exact: Bool)] = []
        for entry in all {
            for alias in entry.aliases { table.append((alias, entry.unit, false)) }
            for alias in entry.exactAliases { table.append((alias, entry.unit, true)) }
        }
        return table.sorted {
            $0.alias.count != $1.alias.count ? $0.alias.count > $1.alias.count : ($0.exact && !$1.exact)
        }
    }()

    /// The unit `word` names exactly (no extra text around it).
    static func named(_ word: String) -> MeasureUnit? {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        for entry in aliasTable {
            if entry.exact ? trimmed == entry.alias : trimmed.lowercased() == entry.alias { return entry.unit }
        }
        return nil
    }

    /// The unit at the end of `text` and the text before it. The alias
    /// must not continue a word ("10km" works, "10 xkm" does not).
    static func trailing(in text: String) -> (unit: MeasureUnit, rest: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        let length = trimmed.count
        for entry in aliasTable where length > entry.alias.count {
            let matches = entry.exact ? trimmed.hasSuffix(entry.alias) : lower.hasSuffix(entry.alias)
            guard matches else { continue }
            let rest = String(trimmed.dropLast(entry.alias.count))
            if let before = rest.last, before.isLetter { continue }
            return (entry.unit, rest)
        }
        return nil
    }

    /// The Foundation unit used for the arithmetic.
    var dimension: Dimension {
        switch symbol {
        case "mm": UnitLength.millimeters
        case "cm": UnitLength.centimeters
        case "m": UnitLength.meters
        case "km": UnitLength.kilometers
        case "in": UnitLength.inches
        case "ft": UnitLength.feet
        case "yd": UnitLength.yards
        case "mi": UnitLength.miles
        case "nmi": UnitLength.nauticalMiles
        case "mg": UnitMass.milligrams
        case "g": UnitMass.grams
        case "kg": UnitMass.kilograms
        case "t": UnitMass.metricTons
        case "oz": UnitMass.ounces
        case "lb": UnitMass.pounds
        case "st": UnitMass.stones
        case "°C": UnitTemperature.celsius
        case "°F": UnitTemperature.fahrenheit
        case "K": UnitTemperature.kelvin
        case "ml": UnitVolume.milliliters
        case "l": UnitVolume.liters
        case "tsp": UnitVolume.teaspoons
        case "tbsp": UnitVolume.tablespoons
        // Foundation's cups is the 240 ml "legal" cup; people mean the US cup.
        case "cup": UnitVolume(symbol: "cup", converter: UnitConverterLinear(coefficient: 0.2365882365))
        case "fl oz": UnitVolume.fluidOunces
        case "pt": UnitVolume.pints
        case "qt": UnitVolume.quarts
        case "gal": UnitVolume.gallons
        case "mm²": UnitArea.squareMillimeters
        case "cm²": UnitArea.squareCentimeters
        case "m²": UnitArea.squareMeters
        case "km²": UnitArea.squareKilometers
        case "ha": UnitArea.hectares
        case "acre": UnitArea.acres
        case "ft²": UnitArea.squareFeet
        case "in²": UnitArea.squareInches
        case "m/s": UnitSpeed.metersPerSecond
        case "km/h": UnitSpeed.kilometersPerHour
        case "mph": UnitSpeed.milesPerHour
        case "kn": UnitSpeed.knots
        case "ms": UnitDuration.milliseconds
        case "s": UnitDuration.seconds
        case "min": UnitDuration.minutes
        case "h": UnitDuration.hours
        case "d": UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
        case "wk": UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))
        case "bit": UnitInformationStorage.bits
        case "B": UnitInformationStorage.bytes
        case "KB": UnitInformationStorage.kilobytes
        case "MB": UnitInformationStorage.megabytes
        case "GB": UnitInformationStorage.gigabytes
        case "TB": UnitInformationStorage.terabytes
        case "kbit": UnitInformationStorage.kilobits
        case "Mbit": UnitInformationStorage.megabits
        case "Gbit": UnitInformationStorage.gigabits
        case "Tbit": UnitInformationStorage.terabits
        case "KiB": UnitInformationStorage.kibibytes
        case "MiB": UnitInformationStorage.mebibytes
        case "GiB": UnitInformationStorage.gibibytes
        default: UnitInformationStorage.tebibytes
        }
    }
}
