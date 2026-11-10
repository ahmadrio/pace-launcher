import Testing
@testable import DOTLauncherCore

struct EmojiCatalogTests {
    private let all = EmojiCatalog.all

    @Test func `the catalog has single emoji and flags only`() {
        #expect(all.first { $0.character == "😀" }?.name == "Grinning face")
        for character in ["❤️", "☀️", "✔️"] {
            #expect(all.contains { $0.character == character }, "\(character)")
        }
        let excluded = Set(["0", "1", "#", "*", "©", "®", "©️", "®️", "🏻"])
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
        let faces = EmojiCatalog.search("sleeping face", usage: ["😴": 5], limit: 30)
        #expect(faces.first?.character == "😴")
    }
}
