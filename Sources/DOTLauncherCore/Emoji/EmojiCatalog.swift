import Foundation

/// One emoji the picker can paste.
public struct Emoji: Sendable, Equatable, Identifiable {
    /// Includes U+FE0F for emoji that default to text presentation.
    public let character: String
    /// Sentence case: "Grinning face", "Flag: Indonesia".
    public let name: String
    /// Lowercased words that also find it ("love", "cinta").
    public let keywords: [String]
    public var id: String { character }

    public init(character: String, name: String, keywords: [String]) {
        self.character = character
        self.name = name
        self.keywords = keywords
    }
}

public enum EmojiCatalog {
    /// Single-character emoji in Unicode order, then country flags by name.
    public static let all: [Emoji] = scalarEmoji() + flags()

    /// Ranked by name and keywords; emoji used often rank higher. With no
    /// query: used emoji (most used first), then the catalog order.
    public static func search(_ query: String, usage: [String: Double], limit: Int) -> [Emoji] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            let used = all.filter { (usage[$0.character] ?? 0) > 0 }
                .sorted { (usage[$0.character] ?? 0) > (usage[$1.character] ?? 0) }
            let rest = all.filter { (usage[$0.character] ?? 0) <= 0 }
            return Array((used + rest).prefix(limit))
        }
        var ranked = candidates
        for index in ranked.indices {
            ranked[index].frecency = usage[ranked[index].id] ?? 0
        }
        return ResultRanker.rank(trimmed, ranked, limit: limit).compactMap { byCharacter[$0] }
    }

    // Prepared once: building the fuzzy targets on every keystroke is slow.
    private static let candidates = all.map { SearchCandidate(id: $0.character, title: $0.name, aliases: $0.keywords) }
    private static let byCharacter = Dictionary(all.map { ($0.character, $0) }) { first, _ in first }

    private static func scalarEmoji() -> [Emoji] {
        let popular = Dictionary(popularTable.map { ($0.emoji.unicodeScalars.first!.value, $0) }) { first, _ in first }
        var result: [Emoji] = []
        for range in [0x2000...0x2BFF, 0x1F000...0x1FAFF] {
            for value in range {
                guard let scalar = Unicode.Scalar(UInt32(value)) else { continue }
                let properties = scalar.properties
                guard properties.isEmoji, !properties.isEmojiModifier,
                      properties.generalCategory == .otherSymbol || properties.generalCategory == .mathSymbol,
                      !(0x1F1E6...0x1F1FF).contains(value),
                      let unicodeName = properties.name, !unicodeName.hasPrefix("EMOJI COMPONENT")
                else { continue }
                // Text-default emoji (❤, ☀) need the variation selector to show in colour.
                let character = String(scalar) + (properties.isEmojiPresentation ? "" : "\u{FE0F}")
                let entry = popular[UInt32(value)]
                result.append(Emoji(character: character, name: entry?.name ?? sentenceCase(unicodeName), keywords: entry?.keywords ?? []))
            }
        }
        return result
    }

    /// "🇮🇩 Flag: Indonesia" for every two-letter region with an English name;
    /// the Indonesian name and the code are keywords ("jepang", "jp").
    private static func flags() -> [Emoji] {
        let english = Locale(identifier: "en"), indonesian = Locale(identifier: "id")
        var result: [Emoji] = []
        for region in Locale.Region.isoRegions {
            let code = region.identifier.uppercased()
            guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }),
                  let name = english.localizedString(forRegionCode: code), name != code
            else { continue }
            let flag = String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 65) }))
            var keywords = [name.lowercased()]
            if let local = indonesian.localizedString(forRegionCode: code)?.lowercased(), local != keywords[0] {
                keywords.append(local)
            }
            keywords.append(code.lowercased())
            result.append(Emoji(character: flag, name: "Flag: " + name, keywords: keywords))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func sentenceCase(_ unicodeName: String) -> String {
        let lower = unicodeName.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    /// Everyday names (Unicode's can be odd: "HEAVY BLACK HEART") and
    /// English + Indonesian keywords for the emoji people use most.
    private static let popularTable: [(emoji: String, name: String?, keywords: [String])] = [
        ("❤", "Red heart", ["love", "cinta", "heart", "sayang"]),
        ("😂", nil, ["lol", "laugh", "ketawa", "ngakak"]),
        ("🙏", "Folded hands", ["thanks", "please", "terima kasih", "makasih", "tolong"]),
        ("👍", "Thumbs up", ["like", "ok", "setuju", "oke"]),
        ("😭", nil, ["cry", "nangis", "sedih"]),
        ("😊", nil, ["smile", "senyum", "happy", "senang"]),
        ("🔥", nil, ["fire", "lit", "api", "keren"]),
        ("🎉", "Party popper", ["party", "selamat", "congrats", "yay"]),
        ("✅", nil, ["done", "check", "selesai", "beres"]),
        ("🤔", nil, ["think", "hmm", "mikir"]),
        ("👀", nil, ["eyes", "look", "lihat"]),
        ("😅", nil, ["sweat", "awkward", "hehe"]),
        ("😍", nil, ["love eyes", "suka"]),
        ("🥲", nil, ["terharu", "smile tear"]),
        ("😎", nil, ["cool", "keren"]),
        ("💯", nil, ["hundred", "perfect", "mantap"]),
        ("🚀", nil, ["launch", "rocket", "roket"]),
        ("👋", nil, ["hello", "halo", "wave", "dadah"]),
        ("😢", nil, ["sad", "sedih"]),
        ("😡", nil, ["angry", "marah"]),
        ("🤣", nil, ["rofl", "ngakak"]),
        ("😴", nil, ["sleep", "tidur", "ngantuk"]),
        ("🙌", nil, ["hooray", "yes", "hore"]),
        ("👏", nil, ["clap", "tepuk tangan", "bravo"]),
        ("💪", nil, ["strong", "kuat", "semangat"]),
        ("☕", nil, ["coffee", "kopi"]),
        ("🍜", nil, ["noodles", "mie"]),
        ("🍚", nil, ["rice", "nasi"]),
        ("📌", nil, ["pin", "penting"]),
        ("⚠", nil, ["warning", "peringatan", "awas"]),
        ("❌", nil, ["no", "cancel", "salah", "batal"]),
        ("⭐", nil, ["star", "bintang"]),
        ("💡", nil, ["idea", "ide"]),
        ("📝", nil, ["note", "catatan"]),
        ("📅", nil, ["calendar", "kalender", "jadwal"]),
        ("⏰", nil, ["alarm", "jam"]),
        ("🎂", nil, ["birthday", "ulang tahun"]),
        ("🤝", nil, ["deal", "salaman", "kerja sama"]),
        ("👌", nil, ["ok", "oke", "sip"]),
        ("🥳", nil, ["celebrate", "pesta"]),
    ]
}
