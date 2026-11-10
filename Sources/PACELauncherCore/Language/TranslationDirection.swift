import Foundation

/// Which way to translate, as base language codes.
public struct TranslationDirection: Sendable, Equatable {
    public let source: String
    public let target: String

    public init(source: String, target: String) {
        self.source = source
        self.target = target
    }

    /// Picks a direction from the detected language. The user's own
    /// language (`home`) goes to `foreign`; anything else comes home.
    /// Malay is close enough to Indonesian that detectors confuse them.
    public static func auto(
        detected: String?, home: String = "id", foreign: String = "en", swapped: Bool = false
    ) -> TranslationDirection {
        let isHome = detected == home || (home == "id" && detected == "ms")
        let direction = switch detected {
        case _ where isHome: TranslationDirection(source: home, target: foreign)
        case nil: TranslationDirection(source: foreign, target: home)
        case let language?: TranslationDirection(source: language, target: home)
        }
        return swapped ? TranslationDirection(source: direction.target, target: direction.source) : direction
    }

    /// "Indonesian → English"
    public var label: String {
        "\(Self.name(of: source)) → \(Self.name(of: target))"
    }

    private static func name(of code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    }
}
