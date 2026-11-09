import DOTLauncherCore
import Foundation
import FoundationModels
import Observation

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    enum Phase: Equatable {
        case streaming
        case translating
        case done
        case failed(String)
    }

    let id = UUID()
    let role: Role
    var text: String
    /// The English answer, kept when `text` holds its translation.
    var original: String?
    var phase: Phase
    /// The answer streams in English and will be translated when done.
    var isBridged = false
}

/// A chat with Apple's on-device model. Questions in languages the model
/// does not support (Indonesian) go through on-device translation.
@Observable
final class AIChatController {
    private static let instructions = "You are a concise assistant inside a macOS launcher. Answer briefly and use Markdown when it helps."

    private(set) var messages: [ChatMessage] = []
    var showOriginal = false

    @ObservationIgnored private let translator: Translator
    @ObservationIgnored private var session = LanguageModelSession(instructions: AIChatController.instructions)
    @ObservationIgnored private var generation: Task<Void, Never>?

    init(translator: Translator) {
        self.translator = translator
    }

    var isGenerating: Bool { generation != nil }

    /// The text of the latest finished answer, as currently displayed.
    var lastAnswer: String? {
        guard let answer = messages.last(where: { $0.role == .assistant && $0.phase == .done }) else { return nil }
        return showOriginal ? (answer.original ?? answer.text) : answer.text
    }

    var lastAnswerHasOriginal: Bool {
        messages.last(where: { $0.role == .assistant })?.original != nil
    }

    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "This Mac does not support Apple Intelligence, which AI Chat needs."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in System Settings to use AI Chat."
        case .unavailable(.modelNotReady):
            "The on-device model is still getting ready. Try again in a few minutes."
        case .unavailable:
            "The on-device model is unavailable right now."
        }
    }

    func prewarm() {
        guard unavailableReason == nil else { return }
        session.prewarm()
    }

    func send(_ prompt: String) {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }

        messages.append(ChatMessage(role: .user, text: prompt, phase: .done))
        let answer = ChatMessage(role: .assistant, text: "", phase: .streaming)
        messages.append(answer)

        if let reason = unavailableReason {
            update(answer.id) { $0.phase = .failed(reason) }
            return
        }

        showOriginal = false
        generation = Task {
            await respond(to: prompt, answerID: answer.id)
            generation = nil
        }
    }

    /// Stops a running answer. Returns false when nothing was running.
    func cancel() -> Bool {
        guard let generation else { return false }
        generation.cancel()
        return true
    }

    func reset() {
        generation?.cancel()
        generation = nil
        messages = []
        showOriginal = false
        session = LanguageModelSession(instructions: Self.instructions)
        prewarm()
    }

    // MARK: - Private

    private func respond(to prompt: String, answerID: UUID) async {
        let supported = Set(SystemLanguageModel.default.supportedLanguages.compactMap { $0.languageCode?.identifier })
        let route = ChatLanguageRoute.route(detected: LanguageDetector.dominantLanguage(of: prompt), supported: supported)

        var modelPrompt = prompt
        var bridgeLanguage: String?
        if case .bridge(let language) = route {
            let toEnglish = TranslationDirection(source: language, target: "en")
            let back = TranslationDirection(source: "en", target: language)
            guard await translator.availability(toEnglish) == .ready, await translator.availability(back) == .ready else {
                update(answerID) { $0.phase = .failed(toEnglish.installHint + " Or ask in English.") }
                return
            }
            do {
                modelPrompt = try await translator.translate(prompt, toEnglish)
            } catch {
                update(answerID) { $0.phase = .failed("Could not translate the question: \(error.localizedDescription)") }
                return
            }
            bridgeLanguage = language
            update(answerID) { $0.isBridged = true }
        }

        do {
            for try await snapshot in session.streamResponse(to: modelPrompt) {
                if Task.isCancelled { break }
                update(answerID) { $0.text = snapshot.content }
            }
        } catch {
            if Task.isCancelled {
                update(answerID) { $0.phase = .done }
            } else {
                update(answerID) { $0.phase = .failed(Self.message(for: error)) }
            }
            return
        }

        guard let language = bridgeLanguage, !Task.isCancelled,
              let english = messages.first(where: { $0.id == answerID })?.text
        else {
            update(answerID) {
                $0.phase = .done
                $0.isBridged = false
            }
            return
        }

        update(answerID) { $0.phase = .translating }
        do {
            let translated = try await translateProse(of: english, to: language)
            update(answerID) {
                $0.original = english
                $0.text = translated
                $0.phase = .done
                $0.isBridged = false
            }
        } catch {
            update(answerID) { $0.phase = .failed("Could not translate the answer: \(error.localizedDescription)") }
        }
    }

    /// Translates prose back to `language`; code is left as written.
    private func translateProse(of markdown: String, to language: String) async throws -> String {
        let direction = TranslationDirection(source: "en", target: language)
        var result: [MarkdownSegment] = []
        for segment in MarkdownSegments.split(markdown) {
            guard case .prose(let prose) = segment else {
                result.append(segment)
                continue
            }
            // Translate the words but keep surrounding blank lines and spaces.
            let core = prose.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !core.isEmpty, let range = prose.range(of: core) else {
                result.append(segment)
                continue
            }
            let translated = try await translator.translate(core, direction)
            result.append(.prose(String(prose[..<range.lowerBound]) + translated + String(prose[range.upperBound...])))
        }
        return MarkdownSegments.join(result)
    }

    private func update(_ id: UUID, _ change: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }

    private static func message(for error: any Error) -> String {
        guard let error = error as? LanguageModelError else { return error.localizedDescription }
        switch error {
        case .contextSizeExceeded:
            return "This chat is too long. Start a new one with ⌘N."
        case .guardrailViolation, .refusal:
            return "The on-device model declined to answer this."
        default:
            return error.localizedDescription
        }
    }
}
