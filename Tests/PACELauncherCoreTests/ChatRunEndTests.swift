import Testing
@testable import PACELauncherCore

struct ChatRunEndTests {
    private let exchange = [
        SavedChatMessage(role: .user, text: "apa itu mesin uap?", original: "what is a steam engine?"),
        SavedChatMessage(role: .assistant, text: "A steam engine…", original: nil),
    ]

    private func end(_ stage: ChatRunStage, cancelled: Bool) -> ChatRunEnd {
        ChatRunEnd.resolve(stage: stage, cancelled: cancelled, error: "offline",
                           question: "apa itu mesin uap?", questionEnglish: "what is a steam engine?", english: "A steam engine…")
    }

    @Test func `cancelling the question translation stops quietly`() {
        let result = end(.translatingQuestion, cancelled: true)
        #expect(result.display == .done)
        #expect(result.saved == nil)
    }

    @Test func `a failed question translation shows the error`() {
        let result = end(.translatingQuestion, cancelled: false)
        #expect(result.display == .failed("Could not translate the question: offline"))
        #expect(result.saved == nil)
    }

    @Test func `cancelling the answer translation keeps the English answer`() {
        let result = end(.translatingAnswer, cancelled: true)
        #expect(result.display == .done)
        #expect(result.saved == exchange)
    }

    @Test func `a failed answer translation keeps the English answer and shows the error`() {
        let result = end(.translatingAnswer, cancelled: false)
        #expect(result.display == .failed("Could not translate the answer: offline"))
        #expect(result.saved == exchange)
    }
}
