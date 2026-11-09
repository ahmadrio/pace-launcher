import DOTLauncherCore
import Foundation
// The framework's async methods are not `nonisolated(nonsending)` and its
// types are not Sendable, so Swift 6 flags calling them on main-actor
// state. All calls here start on the main actor, one at a time.
@preconcurrency import Translation

/// On-device translation through Apple's Translation framework, limited to
/// language pairs that are already downloaded.
final class Translator {
    enum Availability {
        case ready
        /// Supported, but the languages are not downloaded yet.
        case notInstalled
        case unsupported
    }

    private let languages = LanguageAvailability()
    private var sessions: [String: TranslationSession] = [:]

    func availability(_ direction: TranslationDirection) async -> Availability {
        let status = await languages.status(
            from: Locale.Language(identifier: direction.source),
            to: Locale.Language(identifier: direction.target)
        )
        return switch status {
        case .installed: .ready
        case .supported: .notInstalled
        default: .unsupported
        }
    }

    func translate(_ text: String, _ direction: TranslationDirection) async throws -> String {
        try await session(for: direction).translate(text).targetText
    }

    /// Sessions are reused per language pair; creating one loads models.
    private func session(for direction: TranslationDirection) -> TranslationSession {
        let key = direction.source + ">" + direction.target
        if let session = sessions[key] { return session }
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: direction.source),
            target: Locale.Language(identifier: direction.target)
        )
        sessions[key] = session
        return session
    }
}

extension TranslationDirection {
    /// Shown when a pair is supported but not downloaded.
    var installHint: String {
        "Download \(label.replacingOccurrences(of: " → ", with: " and ")) in System Settings → General → Language & Region → Translation Languages."
    }
}
