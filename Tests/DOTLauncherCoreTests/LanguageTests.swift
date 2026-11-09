import Testing
@testable import DOTLauncherCore

struct LanguageTests {
    @Test func `detects Indonesian`() {
        #expect(LanguageDetector.dominantLanguage(of: "Selamat pagi, apa kabar hari ini? Saya ingin memesan kopi.") == "id")
    }

    @Test func `detects English`() {
        #expect(LanguageDetector.dominantLanguage(of: "Good morning, how are you today? I would like to order coffee.") == "en")
    }

    @Test func `Malay is reported as Indonesian`() {
        // Detectors confuse the two; for this app's user Malay means Indonesian,
        // and the translator and the AI bridge must agree on it.
        #expect(LanguageDetector.normalized("ms") == "id")
        #expect(LanguageDetector.normalized("en") == "en")
    }

    @Test func `too short is undetermined`() {
        #expect(LanguageDetector.dominantLanguage(of: "ok") == nil)
        #expect(LanguageDetector.dominantLanguage(of: "   ") == nil)
    }

    @Test(arguments: [
        ("id", false, "id", "en"),
        ("ms", false, "id", "en"),
        ("en", false, "en", "id"),
        ("fr", false, "fr", "id"),
        (nil, false, "en", "id"),
        ("en", true, "id", "en"),
    ] as [(String?, Bool, String, String)])
    func `picks the direction`(detected: String?, swapped: Bool, source: String, target: String) {
        let direction = TranslationDirection.auto(detected: detected, swapped: swapped)
        #expect(direction.source == source)
        #expect(direction.target == target)
    }

    @Test func `labels in English`() {
        #expect(TranslationDirection.auto(detected: "id").label == "Indonesian → English")
    }

    @Test func `can be built explicitly`() {
        let direction = TranslationDirection(source: "ja", target: "en")
        #expect(direction.label == "Japanese → English")
    }
}
