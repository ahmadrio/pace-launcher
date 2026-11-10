/// The words and signs people type for currencies.
public enum CurrencyNames {
    private static let symbols: [String: String] = [
        "$": "USD", "us$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "rp": "IDR", "rp.": "IDR",
        "s$": "SGD", "rm": "MYR", "₩": "KRW", "₹": "INR", "฿": "THB", "₱": "PHP",
    ]

    /// "pound" is missing on purpose: it is a mass unit (unit names win).
    private static let names: [String: String] = [
        "dollar": "USD", "dollars": "USD", "euro": "EUR", "euros": "EUR", "rupiah": "IDR",
        "yen": "JPY", "ringgit": "MYR", "baht": "THB", "won": "KRW", "rupee": "INR", "rupees": "INR",
        "riyal": "SAR", "riyals": "SAR", "dirham": "AED", "dirhams": "AED", "yuan": "CNY", "renminbi": "CNY",
    ]

    /// Codes that work without a target ("100 usd"). Rarer codes need one
    /// ("10 top to idr"), so a stray word never triggers a rates download.
    private static let everyday: Set<String> = [
        "USD", "EUR", "GBP", "JPY", "IDR", "SGD", "MYR", "AUD", "CNY", "KRW", "INR", "THB",
        "PHP", "SAR", "AED", "HKD", "CHF", "CAD", "NZD", "TWD", "VND",
    ]

    /// Active ISO 4217 codes.
    private static let iso: Set<String> = Set("""
        AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD
        CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP FOK GBP GEL GGP GHS
        GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS IMP INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KID
        KMF KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN
        NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD
        SHP SLE SLL SOS SRD SSP STN SYP SZL THB TJS TMT TND TOP TRY TTD TVD TWD TZS UAH UGX USD UYU UZS VES
        VND VUV WST XAF XCD XDR XOF XPF YER ZAR ZMW ZWL
        VED XCG ZWG
        """.split(whereSeparator: \.isWhitespace).map(String.init))

    /// The ISO code a symbol, name or code stands for.
    public static func code(for word: String) -> String? {
        let lower = word.trimmingCharacters(in: .whitespaces).lowercased()
        if let code = symbols[lower] ?? names[lower] { return code }
        let upper = lower.uppercased()
        return iso.contains(upper) ? upper : nil
    }

    /// Signs that may stand before the amount ("$25", "Rp 50.000"). Codes
    /// and names only follow it, so "php 8.3" stays a search.
    public static func isSymbol(_ word: String) -> Bool {
        symbols[word.trimmingCharacters(in: .whitespaces).lowercased()] != nil
    }

    /// True for words that may be converted without a target: symbols,
    /// names and everyday codes.
    public static func worksAlone(_ word: String) -> Bool {
        let lower = word.trimmingCharacters(in: .whitespaces).lowercased()
        if symbols[lower] != nil || names[lower] != nil { return true }
        return everyday.contains(lower.uppercased())
    }
}
