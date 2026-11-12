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
    /// Every emoji Unicode recommends, without skin tones: single code points
    /// (faces first), each followed by the sequences built on it (🤷 🤷‍♂️ 🤷‍♀️),
    /// then keycaps, then flags by name.
    public static let all: [Emoji] = catalog()

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
    /// since the modifier already asks for colour (☝️ → ☝🏽). Sequences take
    /// Unicode's form with one tone for every person (🧑‍🤝‍🧑 → 🧑🏽‍🤝‍🧑🏽), or
    /// stay as they are when Unicode has none (👨‍👩‍👧).
    public static func toned(_ emoji: Emoji, skinTone: EmojiSkinTone) -> Emoji {
        guard let modifier = skinTone.modifier else { return emoji }
        if let template = sequenceTones[emoji.character] {
            var view = String.UnicodeScalarView()
            for scalar in template {
                if scalar.value == mediumTone { view.append(contentsOf: modifier.unicodeScalars) } else { view.append(scalar) }
            }
            return Emoji(character: String(view), name: emoji.name, keywords: emoji.keywords)
        }
        guard emoji.character.unicodeScalars.count(where: { $0.value != variationSelector }) == 1,
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

    /// Modifier bases with no standard toned form (👪): apps that draw their
    /// own emoji would show the base plus a colour swatch. 👯 and 🤼 have
    /// one since Unicode 17.
    private static let untonedBases: Set<UInt32> = [0x1F46A]

    private static let variationSelector: UInt32 = 0xFE0F
    private static let mediumTone: UInt32 = 0x1F3FD

    // Prepared once: building the fuzzy targets on every keystroke is slow.
    private static let candidates = all.map { SearchCandidate(id: $0.character, title: $0.name, aliases: $0.keywords) }
    private static let byCharacter = Dictionary(all.map { ($0.character, $0) }) { first, _ in first }
    private static let popular = Dictionary(popularTable.map { (withoutVariationSelectors($0.emoji), $0) }) { first, _ in first }

    /// One sequence from `sequenceData` and its medium-tone form, if any.
    private struct SequenceEntry {
        let emoji: Emoji
        let mediumTone: [Unicode.Scalar]?
    }

    private static let sequences: [SequenceEntry] = sequenceData.split(separator: "\n").map { line in
        let fields = line.split(separator: ";", omittingEmptySubsequences: false)
        func scalars(_ field: Substring) -> [Unicode.Scalar] {
            field.split(separator: " ").map { Unicode.Scalar(UInt32($0, radix: 16)!)! }
        }
        let character = String(String.UnicodeScalarView(scalars(fields[0])))
        let entry = popular[withoutVariationSelectors(character)]
        // CLDR names keep their capitals ("flag: England" → "Flag: England").
        let name = fields[1].prefix(1).uppercased() + fields[1].dropFirst()
        let emoji = Emoji(character: character, name: entry?.name ?? name, keywords: entry?.keywords ?? [])
        return SequenceEntry(emoji: emoji, mediumTone: fields.count > 2 ? scalars(fields[2]) : nil)
    }

    private static let sequenceTones: [String: [Unicode.Scalar]] = Dictionary(
        sequences.compactMap { sequence in sequence.mediumTone.map { (sequence.emoji.character, $0) } }
    ) { first, _ in first }

    private static func catalog() -> [Emoji] {
        // Sequences follow the emoji they start with; flags join the
        // country flags; the rest (keycaps) close the symbols.
        var byBase: [String: [Emoji]] = [:]
        var subdivisionFlags: [Emoji] = []
        var unplaced: [Emoji] = []
        let single = scalarEmoji()
        let singleBases = Set(single.map { withoutVariationSelectors($0.character) })
        for sequence in sequences.map(\.emoji) {
            let base = sequence.character.unicodeScalars.first.map { String($0) } ?? ""
            if sequence.name.hasPrefix("Flag: ") {
                // Found by the place name, like the country flags ("england").
                let place = sequence.name.dropFirst("Flag: ".count).lowercased()
                subdivisionFlags.append(Emoji(character: sequence.character, name: sequence.name, keywords: [place] + sequence.keywords))
            } else if singleBases.contains(base) {
                byBase[base, default: []].append(sequence)
            } else {
                unplaced.append(sequence)
            }
        }
        var result: [Emoji] = []
        for emoji in single {
            result.append(emoji)
            result += byBase[withoutVariationSelectors(emoji.character)] ?? []
        }
        return result + unplaced + flags(adding: subdivisionFlags)
    }

    private static func scalarEmoji() -> [Emoji] {
        var result: [Emoji] = []
        // Faces first, then other pictures, then symbols: plain Unicode order
        // would open the picker on ™ and arrows. © and ® close the symbols.
        let ranges = [0x1F600...0x1F64F, 0x1F900...0x1FAFF, 0x1F300...0x1F5FF, 0x1F680...0x1F8FF, 0x1F000...0x1F2FF, 0x2000...0x2BFF, 0x3000...0x32FF, 0xA9...0xAE]
        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(UInt32(value)) else { continue }
                let properties = scalar.properties
                // No category filter: ‼ ⁉ are punctuation and ℹ is a letter, yet emoji.
                // ASCII is left out, so # * 0–9 appear only as keycaps (1️⃣).
                guard properties.isEmoji, !properties.isEmojiModifier,
                      !(0x1F1E6...0x1F1FF).contains(value),
                      let unicodeName = properties.name, !unicodeName.hasPrefix("EMOJI COMPONENT")
                else { continue }
                // Text-default emoji (❤, ☀, ©) need the variation selector to show in colour.
                let character = String(scalar) + (properties.isEmojiPresentation ? "" : "\u{FE0F}")
                let entry = popular[String(scalar)]
                result.append(Emoji(character: character, name: entry?.name ?? sentenceCase(unicodeName), keywords: entry?.keywords ?? []))
            }
        }
        return result
    }

    private static func withoutVariationSelectors(_ character: String) -> String {
        String(String.UnicodeScalarView(character.unicodeScalars.filter { $0.value != variationSelector }))
    }

    /// "🇮🇩 Flag: Indonesia" for every two-letter region with an English name;
    /// the Indonesian name and the code are keywords ("jepang", "jp"). Flags
    /// from `sequenceData` (England) sort among them.
    private static func flags(adding extra: [Emoji]) -> [Emoji] {
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
        return (result + extra).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Region codes Apple's emoji font has no flag for (they show as letters).
    private static let flaglessRegions: Set<String> = ["EZ", "QO"]

    private static func sentenceCase(_ unicodeName: String) -> String {
        let lower = unicodeName.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    /// Everyday names (Unicode's can be odd: "HEAVY BLACK HEART") and
    /// English + Indonesian keywords for the emoji people use most. Written
    /// without U+FE0F; sequences are matched whole.
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
        ("🧑‍💻", nil, ["programmer", "developer", "coding", "ngoding"]),
        ("😮‍💨", nil, ["sigh", "lega", "capek"]),
        ("🏳‍🌈", nil, ["pride"]),
    ]
}
