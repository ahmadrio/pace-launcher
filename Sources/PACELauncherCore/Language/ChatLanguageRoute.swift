/// How a chat message reaches the on-device model.
public enum ChatLanguageRoute: Equatable, Sendable {
    /// The model understands the language (or it could not be detected).
    case direct
    /// Translate to English first, and the answer back afterwards.
    case bridge(language: String)

    public static func route(detected: String?, supported: Set<String>) -> ChatLanguageRoute {
        guard let detected, !supported.contains(detected) else { return .direct }
        return .bridge(language: detected)
    }
}
