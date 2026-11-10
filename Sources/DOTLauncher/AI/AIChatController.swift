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
    /// The chat that finished exchanges are saved to.
    private(set) var chatID = UUID()

    @ObservationIgnored private let translator: Translator
    @ObservationIgnored private let store: ChatStore?
    @ObservationIgnored private var session = LanguageModelSession(instructions: AIChatController.instructions)
    @ObservationIgnored private var generation: Task<Void, Never>?
    /// Only the latest answer's task may clear `generation`.
    @ObservationIgnored private var runs = RunToken()

    init(translator: Translator, store: ChatStore?) {
        self.translator = translator
        self.store = store
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
        let run = runs.begin()
        generation = Task {
            await respond(to: prompt, answerID: answer.id)
            if runs.isCurrent(run) { generation = nil }
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
        chatID = UUID()
        session = LanguageModelSession(instructions: Self.instructions)
        prewarm()
    }

    // MARK: - History

    /// Shows a saved chat and continues it with the same context.
    func open(_ id: UUID) async {
        guard let store else { return }
        // A run still answering saves its partial exchange when cancelled;
        // wait for that, so a chat opened mid-answer shows it. `generation`
        // stays set meanwhile, which keeps `send` blocked.
        if let running = generation {
            running.cancel()
            await running.value
        }
        let saved: [SavedChatMessage]
        do {
            saved = try await store.messages(of: id)
        } catch {
            Log.app.error("could not load a chat: \(error.localizedDescription, privacy: .public)")
            return
        }
        generation?.cancel()
        generation = nil
        messages = saved.map { message in
            ChatMessage(
                role: message.role == .user ? .user : .assistant,
                text: message.text,
                original: message.role == .assistant ? message.original : nil,
                phase: .done
            )
        }
        showOriginal = false
        chatID = id
        session = LanguageModelSession(transcript: Self.transcript(for: saved))
        prewarm()
    }

    func history(matching query: String) async -> [ChatSummary] {
        guard let store else { return [] }
        do {
            return try await store.chats(matching: query)
        } catch {
            Log.app.error("could not list chats: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func delete(_ id: UUID) async {
        // The open chat is cleared first; the store also refuses late saves
        // into a deleted chat (the cancelled answer still tries to save).
        if id == chatID { reset() }
        do {
            try await store?.delete(id)
        } catch {
            Log.app.error("could not delete a chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deleteAll() async {
        // Clear first, like delete: the store also refuses late saves into
        // deleted chats, so a cancelled answer cannot bring one back.
        reset()
        do {
            try await store?.deleteAll()
        } catch {
            Log.app.error("could not delete chats: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The saved messages as the model saw them, after the instructions.
    private static func transcript(for saved: [SavedChatMessage]) -> Transcript {
        var entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(Transcript.TextSegment(content: instructions))], toolDefinitions: [])),
        ]
        for message in saved {
            let segments: [Transcript.Segment] = [.text(Transcript.TextSegment(content: message.modelText))]
            switch message.role {
            case .user: entries.append(.prompt(Transcript.Prompt(segments: segments)))
            case .assistant: entries.append(.response(Transcript.Response(assetIDs: [], segments: segments)))
            }
        }
        return Transcript(entries: entries)
    }

    /// Saves a finished exchange (an answer stopped with Esc, ⌘N or by
    /// opening another chat counts). The text comes from the answering task,
    /// not from `messages`, which may already show another chat.
    private func save(question: String, questionEnglish: String?, answer: String, answerEnglish: String?, chat: UUID) async {
        await save(SavedChatMessage.exchange(
            question: question, questionEnglish: questionEnglish,
            answer: answer, answerEnglish: answerEnglish
        ), chat: chat)
    }

    private func save(_ exchange: [SavedChatMessage]?, chat: UUID) async {
        guard let store, let exchange else { return }
        do {
            try await store.append(exchange, to: chat, at: .now)
        } catch {
            Log.app.error("could not save a chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private

    private func respond(to prompt: String, answerID: UUID) async {
        let chat = chatID
        // Opening another chat replaces `session`; this answer stays with its own.
        let session = self.session
        var answerText = ""
        let supported = Set(SystemLanguageModel.default.supportedLanguages.compactMap { $0.languageCode?.identifier })
        let route = ChatLanguageRoute.route(detected: LanguageDetector.dominantLanguage(of: prompt), supported: supported)

        var modelPrompt = prompt
        var bridgeLanguage: String?
        if case .bridge(let language) = route {
            let toEnglish = TranslationDirection(source: language, target: "en")
            let back = TranslationDirection(source: "en", target: language)
            let availability = [await translator.availability(toEnglish), await translator.availability(back)]
            if availability.contains(.unsupported) {
                // No download would help: say so instead of pointing at Settings.
                let name = Locale(identifier: "en").localizedString(forLanguageCode: language) ?? language
                update(answerID) { $0.phase = .failed("On-device translation does not support \(name). Ask in English.") }
                return
            }
            if availability.contains(.notInstalled) {
                update(answerID) { $0.phase = .failed(toEnglish.installHint + " Or ask in English.") }
                return
            }
            do {
                modelPrompt = try await translator.translate(prompt, toEnglish)
            } catch {
                // Esc or another chat while translating: stop quietly.
                await finish(answerID, ChatRunEnd.resolve(
                    stage: .translatingQuestion, cancelled: Task.isCancelled || error is CancellationError,
                    error: error.localizedDescription, question: prompt, questionEnglish: nil, english: ""
                ), chat: chat)
                return
            }
            // Stopped while translating: send nothing to the model.
            guard !Task.isCancelled else {
                update(answerID) { $0.phase = .done }
                return
            }
            bridgeLanguage = language
            update(answerID) { $0.isBridged = true }
        }

        do {
            for try await snapshot in session.streamResponse(to: modelPrompt) {
                if Task.isCancelled { break }
                answerText = snapshot.content
                update(answerID) { $0.text = snapshot.content }
            }
        } catch {
            if Task.isCancelled {
                update(answerID) { $0.phase = .done }
                await save(question: prompt, questionEnglish: bridgeLanguage == nil ? nil : modelPrompt, answer: answerText, answerEnglish: nil, chat: chat)
            } else {
                update(answerID) { $0.phase = .failed(Self.message(for: error)) }
            }
            return
        }

        guard let language = bridgeLanguage, !Task.isCancelled else {
            update(answerID) {
                $0.phase = .done
                $0.isBridged = false
            }
            await save(question: prompt, questionEnglish: bridgeLanguage == nil ? nil : modelPrompt, answer: answerText, answerEnglish: nil, chat: chat)
            return
        }
        let english = answerText

        update(answerID) { $0.phase = .translating }
        do {
            let translated = try await translateProse(of: english, to: language)
            update(answerID) {
                $0.original = english
                $0.text = translated
                $0.phase = .done
                $0.isBridged = false
            }
            await save(question: prompt, questionEnglish: modelPrompt, answer: translated, answerEnglish: english, chat: chat)
        } catch {
            // The English answer is kept, and a stop shows no error.
            await finish(answerID, ChatRunEnd.resolve(
                stage: .translatingAnswer, cancelled: Task.isCancelled || error is CancellationError,
                error: error.localizedDescription, question: prompt, questionEnglish: modelPrompt, english: english
            ), chat: chat)
        }
    }

    /// Shows how a stopped or failed run ended and saves what it kept.
    private func finish(_ answerID: UUID, _ end: ChatRunEnd, chat: UUID) async {
        update(answerID) {
            switch end.display {
            case .done:
                $0.phase = .done
                $0.isBridged = false
            case .failed(let message):
                $0.phase = .failed(message)
            }
        }
        await save(end.saved, chat: chat)
    }

    /// Translates prose back to `language`, a paragraph at a time; code is
    /// left as written. Esc stops before the next paragraph.
    private func translateProse(of markdown: String, to language: String) async throws -> String {
        let direction = TranslationDirection(source: "en", target: language)
        return try await MarkdownSegments.translateProse(markdown) { try await self.translator.translate($0, direction) }
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
