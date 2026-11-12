import Testing
@testable import PACELauncherCore

struct EmojiCatalogTests {
    private let all = EmojiCatalog.all

    @Test func `the catalog has no bare ASCII or tone modifiers`() {
        #expect(all.first { $0.character == "😀" }?.name == "Grinning face")
        for character in ["❤️", "☀️", "✔️", "©️", "®️"] {
            #expect(all.contains { $0.character == character }, "\(character)")
        }
        let excluded = Set(["0", "1", "#", "*", "©", "®", "🏻"])
        #expect(!all.contains { excluded.contains($0.character) || $0.character.contains("🏻") })
        let lone = all.filter { $0.character.unicodeScalars.count == 1 && (0x1F1E6...0x1F1FF).contains($0.character.unicodeScalars.first!.value) }
        #expect(lone.isEmpty)
        let indonesia = all.first { $0.character == "🇮🇩" }
        #expect(indonesia?.name == "Flag: Indonesia")
        #expect(indonesia?.keywords.contains("indonesia") == true)
        #expect(all.count > 1000)
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test func `popular emoji are found by everyday words`() {
        func first(_ query: String) -> String? { EmojiCatalog.search(query, usage: [:], limit: 5).first?.character }
        #expect(first("love") == "❤️")
        #expect(first("cinta") == "❤️")
        #expect(first("ketawa") == "😂")
        #expect(first("thanks") == "🙏")
        #expect(first("jepang") == "🇯🇵")
        #expect(EmojiCatalog.search("grinning", usage: [:], limit: 30).contains { $0.character == "😀" })
    }

    @Test func `used emoji come first`() {
        let empty = EmojiCatalog.search("", usage: ["🔥": 3, "😀": 1], limit: 10)
        #expect(empty.prefix(2).map(\.character) == ["🔥", "😀"])
        #expect(empty.count == 10)
        // Usage lifts an emoji among others that match the query equally well.
        func rank(of character: String, usage: [String: Double]) -> Int? {
            EmojiCatalog.search("sl", usage: usage, limit: 50).firstIndex { $0.character == character }
        }
        let plain = rank(of: "😴", usage: [:])
        let used = rank(of: "😴", usage: ["😴": 5])
        #expect(plain != nil && used != nil)
        #expect(used! < plain!)
    }

    @Test func `missing emoji and flags are fixed`() {
        for character in ["‼️", "⁉️", "ℹ️", "〰️", "〽️", "㊗️", "㊙️"] {
            #expect(all.contains { $0.character == character }, "\(character)")
        }
        #expect(!all.contains { $0.character == "🇪🇿" || $0.character == "🇶🇴" })
        #expect(!all.contains { ["0", "#", "©"].contains($0.character) })
    }

    @Test func `more everyday words find emoji`() {
        func first(_ query: String) -> String? { EmojiCatalog.search(query, usage: [:], limit: 5).first?.character }
        #expect(first("pray") == "🙏")
        #expect(first("doa") == "🙏")
        #expect(first("100") == "💯")
        #expect(first("tada") == "🎉")
        #expect(first("poop") == "💩")
    }

    @Test func `skin tone changes only emoji that take it`() {
        func toned(_ character: String, _ tone: EmojiSkinTone) -> String {
            EmojiCatalog.toned(Emoji(character: character, name: "x", keywords: ["k"]), skinTone: tone).character
        }
        #expect(toned("👍", .medium) == "👍🏽")
        #expect(toned("☝️", .medium) == "☝🏽")
        #expect(toned("🙏", .medium) == "🙏🏽")
        #expect(toned("👋", .dark) == "👋🏿")
        for character in ["❤️", "🔥", "🇮🇩"] {
            #expect(toned(character, .medium) == character, "\(character)")
        }
        #expect(toned("👍", .default) == "👍")
        let thumbs = EmojiCatalog.toned(Emoji(character: "👍", name: "Thumbs up", keywords: ["like"]), skinTone: .light)
        #expect(thumbs.name == "Thumbs up")
        #expect(thumbs.keywords == ["like"])
        #expect(EmojiSkinTone.dark.next == .default)
        #expect(EmojiSkinTone.default.rawValue == "none")
        #expect(EmojiSkinTone.default.next == .light)
        #expect(EmojiSkinTone.allCases.map(\.title) == ["Default", "Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"])
        #expect(EmojiSkinTone.allCases.map { $0.modifier ?? "" } == ["", "🏻", "🏼", "🏽", "🏾", "🏿"])
    }

    /// "1F9D1 200D 1F4BB" per line → "🧑‍💻".
    private func emojiList(_ lines: String) -> [String] {
        lines.split(separator: "\n").map { line in
            String(String.UnicodeScalarView(line.split(separator: " ").map { Unicode.Scalar(UInt32($0, radix: 16)!)! }))
        }
    }

    @Test func `every Unicode emoji is in the catalog`() {
        let characters = Set(all.map(\.character))
        let missing = emojiList(UnicodeEmojiList.base).filter { !characters.contains($0) }
        #expect(missing.isEmpty, "\(missing.count) missing from Unicode \(UnicodeEmojiList.version): \(missing.prefix(20).joined(separator: " "))")
    }

    @Test func `the catalog holds only Unicode emoji`() {
        let listed = Set(emojiList(UnicodeEmojiList.base))
        let listVersion = Int(UnicodeEmojiList.version.split(separator: ".")[0])!
        // Swift's Unicode data may be newer than the list: new single emoji
        // join by themselves.
        let unlisted = all.filter { emoji in
            guard !listed.contains(emoji.character) else { return false }
            let scalars = emoji.character.unicodeScalars.filter { $0.value != 0xFE0F }
            return scalars.count != 1 || (scalars.first!.properties.age?.major ?? 0) <= listVersion
        }
        #expect(unlisted.isEmpty, "\(unlisted.map(\.character).joined(separator: " "))")
    }

    @Test func `toned emoji match Unicode`() {
        let mediums = Set(emojiList(UnicodeEmojiList.medium))
        var produced: Set<String> = []
        for emoji in all {
            let toned = EmojiCatalog.toned(emoji, skinTone: .medium).character
            guard toned != emoji.character else { continue }
            #expect(mediums.contains(toned), "\(emoji.name): \(toned)")
            produced.insert(toned)
        }
        let unreached = mediums.subtracting(produced)
        #expect(unreached.isEmpty, "no catalog emoji takes these tones: \(unreached.sorted().joined(separator: " "))")
        // 👪 has no standard toned form; 👯 and 🤼 have one since Unicode 17.
        func toned(_ character: String) -> String {
            EmojiCatalog.toned(Emoji(character: character, name: "x", keywords: []), skinTone: .medium).character
        }
        #expect(toned("👪") == "👪")
        #expect(toned("👯") == "👯🏽")
        #expect(toned("🤼") == "🤼🏽")
    }

    @Test func `sequences take skin tones where Unicode has them`() {
        func toned(_ character: String, _ tone: EmojiSkinTone = .medium) -> String? {
            EmojiCatalog.emoji(for: character).map { EmojiCatalog.toned($0, skinTone: tone).character }
        }
        #expect(toned("🧑‍💻") == "🧑🏽‍💻")
        #expect(toned("🧑‍💻", .dark) == "🧑🏿‍💻")
        #expect(toned("🧑‍💻", .default) == "🧑‍💻")
        #expect(toned("🏌️‍♂️") == "🏌🏽‍♂️")
        #expect(toned("🧑‍🤝‍🧑", .light) == "🧑🏻‍🤝‍🧑🏻")
        #expect(toned("👩‍❤️‍👨") == "👩🏽‍❤️‍👨🏽")
        #expect(toned("👯‍♀️") == "👯🏽‍♀️")
        for character in ["👨‍👩‍👧", "🧑‍🧑‍🧒", "❤️‍🔥", "1️⃣", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"] {
            #expect(toned(character) == character, "\(character)")
        }
        #expect(EmojiCatalog.emoji(for: "🧑‍💻").map(EmojiCatalog.canTone) == true)
        #expect(EmojiCatalog.emoji(for: "👨‍👩‍👧").map(EmojiCatalog.canTone) == false)
        // Usage and own tones are keyed by the untoned character.
        let custom = Emoji(character: "🧑‍💻", name: "x", keywords: [])
        #expect(EmojiCatalog.toned(custom, skinTone: .medium).character == "🧑🏽‍💻")
    }

    @Test func `sequences sit next to their base`() {
        func name(_ character: String) -> String? { EmojiCatalog.emoji(for: character)?.name }
        #expect(name("👨‍💻") == "Man technologist")
        #expect(name("1️⃣") == "Keycap: 1")
        #expect(name("👨‍👩‍👧") == "Family: man, woman, girl")
        #expect(name("🏴󠁧󠁢󠁥󠁮󠁧󠁿") == "Flag: England")
        func index(_ character: String) -> Int { all.firstIndex { $0.character == character } ?? -1 }
        #expect(index("🤷‍♂️") == index("🤷") + 1)
        #expect(index("🤷‍♀️") == index("🤷") + 2)
        #expect(index("😮‍💨") == index("😮") + 1)
        #expect(index("❤️‍🔥") > index("❤️") && index("❤️‍🔥") < index("❤️") + 3)
        // Subdivision flags sort with the country flags.
        #expect(index("🇪🇬") < index("🏴󠁧󠁢󠁥󠁮󠁧󠁿") && index("🏴󠁧󠁢󠁥󠁮󠁧󠁿") < index("🇫🇷"))
        #expect(index("🏴󠁧󠁢󠁷󠁬󠁳󠁿") > index("🇻🇳"))
        // Keycaps close the symbols, before the flags.
        #expect(index("#️⃣") > index("〰️") && index("9️⃣") < all.firstIndex { $0.name.hasPrefix("Flag: ") }!)
        func first(_ query: String) -> String? { EmojiCatalog.search(query, usage: [:], limit: 5).first?.character }
        #expect(first("programmer") == "🧑‍💻")
        #expect(first("pride") == "🏳️‍🌈")
        #expect(first("england") == "🏴󠁧󠁢󠁥󠁮󠁧󠁿")
        #expect(first("keycap 1") == "1️⃣")
        #expect(EmojiCatalog.search("technologist", usage: [:], limit: 5).map(\.character).contains("👩‍💻"))
    }

    @Test func `which emoji can be toned`() {
        func can(_ character: String) -> Bool { EmojiCatalog.canTone(Emoji(character: character, name: "x", keywords: [])) }
        #expect(can("👍"))
        #expect(can("☝️"))
        for character in ["❤️", "👪", "🇮🇩"] {
            #expect(!can(character), "\(character)")
        }
    }

    @Test func `per-emoji tones cycle`() {
        var tone: EmojiSkinTone?
        var seen: [EmojiSkinTone?] = []
        for _ in 0..<8 {
            tone = EmojiSkinTone.cycleOverride(tone)
            seen.append(tone)
        }
        #expect(seen == [.default, .light, .mediumLight, .medium, .mediumDark, .dark, nil, .default])
    }
}
