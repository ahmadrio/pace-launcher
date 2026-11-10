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
    /// Single-character emoji (faces first), then country flags by name.
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

    /// The emoji in the chosen skin tone. Only emoji Unicode lists as
    /// modifier bases change (👍 → 👍🏽); the variation selector is dropped,
    /// since the modifier already asks for colour (☝️ → ☝🏽).
    public static func toned(_ emoji: Emoji, skinTone: EmojiSkinTone) -> Emoji {
        guard let modifier = skinTone.modifier,
              let base = emoji.character.unicodeScalars.first, base.properties.isEmojiModifierBase,
              !untonedBases.contains(base.value)
        else { return emoji }
        return Emoji(character: String(base) + modifier, name: emoji.name, keywords: emoji.keywords)
    }

    /// The catalog entry for a base character ("👍", "☝️"), if any.
    public static func emoji(for character: String) -> Emoji? {
        byCharacter[character]
    }

    /// True for hand and person emoji that have skin-tone forms.
    public static func canTone(_ emoji: Emoji) -> Bool {
        toned(emoji, skinTone: .medium) != emoji
    }

    /// Modifier bases with no standard toned form (👪 👯 🤼): apps that
    /// draw their own emoji would show the base plus a colour swatch.
    private static let untonedBases: Set<UInt32> = [0x1F46A, 0x1F46F, 0x1F93C]

    // Prepared once: building the fuzzy targets on every keystroke is slow.
    private static let candidates = all.map { SearchCandidate(id: $0.character, title: $0.name, aliases: $0.keywords) }
    private static let byCharacter = Dictionary(all.map { ($0.character, $0) }) { first, _ in first }

    private static func scalarEmoji() -> [Emoji] {
        let popular = Dictionary(popularTable.map { ($0.emoji.unicodeScalars.first!.value, $0) }) { first, _ in first }
        var result: [Emoji] = []
        // Faces first, then other pictures, then symbols: plain Unicode order
        // would open the picker on ™ and arrows.
        let ranges = [0x1F600...0x1F64F, 0x1F900...0x1FAFF, 0x1F300...0x1F5FF, 0x1F680...0x1F8FF, 0x1F000...0x1F2FF, 0x2000...0x2BFF, 0x3000...0x32FF]
        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(UInt32(value)) else { continue }
                let properties = scalar.properties
                // No category filter: ‼ ⁉ are punctuation and ℹ is a letter, yet emoji.
                // The ranges start above ASCII, so # * 0–9 © ® never appear.
                guard properties.isEmoji, !properties.isEmojiModifier,
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
            guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }), !flaglessRegions.contains(code),
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

    /// Region codes Apple's emoji font has no flag for (they show as letters).
    private static let flaglessRegions: Set<String> = ["EZ", "QO"]

    private static func sentenceCase(_ unicodeName: String) -> String {
        let lower = unicodeName.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    /// Everyday names (Unicode's can be odd: "HEAVY BLACK HEART") and
    /// English + Indonesian keywords for the emoji people use most.
    private static let popularTable: [(emoji: String, name: String?, keywords: [String])] = [
        ("❤", "Red heart", ["love", "cinta", "heart", "sayang"]),
        ("😂", nil, ["lol", "laugh", "ketawa", "ngakak"]),
        ("🙏", "Folded hands", ["thanks", "please", "terima kasih", "makasih", "tolong", "pray", "doa"]),
        ("👍", "Thumbs up", ["like", "ok", "setuju", "oke"]),
        ("😭", nil, ["cry", "nangis", "sedih"]),
        ("😊", nil, ["smile", "senyum", "happy", "senang"]),
        ("🔥", nil, ["fire", "lit", "api", "keren"]),
        ("🎉", "Party popper", ["party", "selamat", "congrats", "yay", "tada"]),
        ("✅", nil, ["done", "check", "selesai", "beres"]),
        ("🤔", nil, ["think", "hmm", "mikir"]),
        ("👀", nil, ["eyes", "look", "lihat"]),
        ("😅", nil, ["sweat", "awkward", "hehe"]),
        ("😍", nil, ["love eyes", "suka"]),
        ("🥲", nil, ["terharu", "smile tear"]),
        ("😎", nil, ["cool", "keren"]),
        ("💯", nil, ["hundred", "perfect", "mantap", "100"]),
        ("💩", "Pile of poo", ["poop", "tai", "poo"]),
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
