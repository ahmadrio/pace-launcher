/// Where a bridged chat run was when it stopped or failed.
public enum ChatRunStage: Sendable { case translatingQuestion, translatingAnswer }

/// How an AI chat run ends when a translation throws: a stop (Esc, ⌘N,
/// another chat) is quiet, and a finished English answer is never lost.
public struct ChatRunEnd: Equatable, Sendable {
    public enum Display: Equatable, Sendable { case done, failed(String) }

    public let display: Display
    /// What to append to the chat; nil saves nothing.
    public let saved: [SavedChatMessage]?

    public static func resolve(stage: ChatRunStage, cancelled: Bool, error: String,
                               question: String, questionEnglish: String?, english: String) -> ChatRunEnd {
        switch stage {
        case .translatingQuestion:
            // No answer yet, so nothing to keep.
            return ChatRunEnd(display: cancelled ? .done : .failed("Could not translate the question: \(error)"), saved: nil)
        case .translatingAnswer:
            // The model's English answer is complete: keep it either way.
            let saved = SavedChatMessage.exchange(question: question, questionEnglish: questionEnglish, answer: english, answerEnglish: nil)
            return ChatRunEnd(display: cancelled ? .done : .failed("Could not translate the answer: \(error)"), saved: saved)
        }
    }
}
