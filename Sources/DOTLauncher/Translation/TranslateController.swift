import DOTLauncherCore
import Foundation
import Observation

/// State of the Translate mode: translates the query as the user types.
@Observable
final class TranslateController {
    enum Status: Equatable {
        case idle
        case translating
        case done
        case failed(String)
    }

    private(set) var direction: TranslationDirection?
    private(set) var output = ""
    private(set) var status = Status.idle

    @ObservationIgnored private let translator: Translator
    @ObservationIgnored private var query = ""
    @ObservationIgnored private var swapped = false
    @ObservationIgnored private var task: Task<Void, Never>?

    init(translator: Translator) {
        self.translator = translator
    }

    func reset() {
        task?.cancel()
        query = ""
        swapped = false
        direction = nil
        output = ""
        status = .idle
    }

    func update(_ query: String) {
        self.query = query
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            reset()
            return
        }
        schedule(after: .milliseconds(300))
    }

    /// Flips the direction for the current text (detection guessed wrong).
    func swap() {
        guard !query.isEmpty else { return }
        swapped.toggle()
        schedule(after: .zero)
    }

    private func schedule(after delay: Duration) {
        task?.cancel()
        let query = query
        let swapped = swapped
        // Results are only written while they still match what the user
        // typed, so a slow older translation never replaces a newer one.
        func isCurrent() -> Bool { self.query == query && self.swapped == swapped }

        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, isCurrent() else { return }

            let direction = TranslationDirection.auto(detected: LanguageDetector.dominantLanguage(of: query), swapped: swapped)
            self.direction = direction
            status = .translating

            switch await translator.availability(direction) {
            case .ready:
                break
            case .notInstalled:
                guard isCurrent() else { return }
                output = ""
                status = .failed(direction.installHint)
                return
            case .unsupported:
                guard isCurrent() else { return }
                output = ""
                status = .failed("\(direction.label) is not supported by on-device translation.")
                return
            }

            do {
                let text = try await translator.translate(query, direction)
                guard isCurrent() else { return }
                output = text
                status = .done
            } catch {
                guard isCurrent(), !Task.isCancelled else { return }
                status = .failed(error.localizedDescription)
            }
        }
    }
}
