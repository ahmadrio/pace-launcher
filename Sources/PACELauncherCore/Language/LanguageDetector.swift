import NaturalLanguage

public enum LanguageDetector {
    /// The dominant language of `text` as a base code ("id", "en", …), or
    /// nil when the text is too short or the language is undetermined.
    public static func dominantLanguage(of text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }

        // NLLanguage raw values can carry a script or region ("zh-Hans").
        return Locale.Language(identifier: language.rawValue).languageCode.map { normalized($0.identifier) }
    }

    /// Detectors confuse Malay with Indonesian; for this app Malay text is
    /// treated as Indonesian so every feature routes it the same way.
    public static func normalized(_ code: String) -> String {
        code == "ms" ? "id" : code
    }
}
