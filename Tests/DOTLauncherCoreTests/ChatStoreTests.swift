import Foundation
import Testing
@testable import DOTLauncherCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func exchange(_ question: String, _ answer: String) -> [SavedChatMessage] {
    [SavedChatMessage(role: .user, text: question), SavedChatMessage(role: .assistant, text: answer)]
}

struct ChatStoreTests {
    @Test func `appending to a new chat creates it with a title from the first question`() async throws {
        let store = try ChatStore(path: ":memory:")
        let id = UUID()

        try await store.append(exchange("How do I zip a folder?\nwith details", "Use ditto"), to: id, at: t0)

        let chats = try await store.chats()
        #expect(chats == [ChatSummary(id: id, title: "How do I zip a folder?", messageCount: 2, updatedAt: t0)])
    }

    @Test func `appending again adds messages in order and moves the chat to the top`() async throws {
        let store = try ChatStore(path: ":memory:")
        let a = UUID(), b = UUID()

        try await store.append(exchange("first question", "first answer"), to: a, at: t0)
        try await store.append(exchange("other chat", "other answer"), to: b, at: t0.addingTimeInterval(30))
        try await store.append(exchange("second question", "second answer"), to: a, at: t0.addingTimeInterval(60))

        let chats = try await store.chats()
        #expect(chats.map(\.id) == [a, b])
        #expect(chats.first?.title == "first question")
        #expect(chats.first?.messageCount == 4)
        #expect(try await store.messages(of: a).map(\.text) == ["first question", "first answer", "second question", "second answer"])
        #expect(try await store.messages(of: a).map(\.role) == [.user, .assistant, .user, .assistant])
    }

    @Test func `search matches titles and message text`() async throws {
        let store = try ChatStore(path: ":memory:")
        let a = UUID(), b = UUID()
        try await store.append(exchange("How do I zip a folder?", "Use ditto -c -k"), to: a, at: t0)
        try await store.append(exchange("Weather", "Sunny, 100% dry"), to: b, at: t0.addingTimeInterval(1))

        #expect(try await store.chats(matching: "ditto").map(\.id) == [a])
        #expect(try await store.chats(matching: "ZIP").map(\.id) == [a])
        #expect(try await store.chats(matching: "nothing here").isEmpty)
        #expect(try await store.chats(matching: "100%").map(\.id) == [b])
        #expect(try await store.chats(matching: "%").map(\.id) == [b])
    }

    @Test func `deleting a chat removes its messages`() async throws {
        let store = try ChatStore(path: ":memory:")
        let a = UUID(), b = UUID()
        try await store.append(exchange("a", "1"), to: a, at: t0)
        try await store.append(exchange("b", "2"), to: b, at: t0)

        try await store.delete(a)

        #expect(try await store.messages(of: a).isEmpty)
        #expect(try await store.chats().map(\.id) == [b])
    }

    @Test func `listing returns more than 100 chats`() async throws {
        let store = try ChatStore(path: ":memory:")
        for index in 0..<150 {
            try await store.append(exchange("question \(index)", "answer"), to: UUID(), at: t0.addingTimeInterval(Double(index)))
        }
        #expect(try await store.chats().count == 150)
    }

    @Test func `delete all empties the history`() async throws {
        let store = try ChatStore(path: ":memory:")
        try await store.append(exchange("a", "1"), to: UUID(), at: t0)
        try await store.append(exchange("b", "2"), to: UUID(), at: t0)

        try await store.deleteAll()

        #expect(try await store.chats().isEmpty)
    }

    @Test func `originals survive a round trip`() async throws {
        let store = try ChatStore(path: ":memory:")
        let id = UUID()
        let saved = [
            SavedChatMessage(role: .user, text: "Apa ibu kota Prancis?", original: "What is the capital of France?"),
            SavedChatMessage(role: .assistant, text: "Paris.", original: "Paris."),
        ]
        try await store.append(saved, to: id, at: t0)

        #expect(try await store.messages(of: id) == saved)
    }

    @Test func `model text prefers the English original`() {
        #expect(SavedChatMessage(role: .user, text: "Halo", original: "Hello").modelText == "Hello")
        #expect(SavedChatMessage(role: .user, text: "Hello").modelText == "Hello")
    }

    @Test func `an exchange with a blank answer is not saved`() {
        #expect(SavedChatMessage.exchange(question: "q", questionEnglish: nil, answer: "  \n", answerEnglish: nil) == nil)

        let saved = SavedChatMessage.exchange(question: "Halo", questionEnglish: "Hello", answer: "Hai", answerEnglish: "Hi")
        #expect(saved == [
            SavedChatMessage(role: .user, text: "Halo", original: "Hello"),
            SavedChatMessage(role: .assistant, text: "Hai", original: "Hi"),
        ])
    }
}

struct ChatTitleTests {
    @Test func `title is the first non-empty line`() {
        #expect(ChatTitle.title(for: "\n\n  Hello  \nmore") == "Hello")
    }

    @Test func `long titles are cut to 80 characters with an ellipsis`() {
        let title = ChatTitle.title(for: String(repeating: "a", count: 81))
        #expect(title.count == 80)
        #expect(title == String(repeating: "a", count: 79) + "…")
        #expect(ChatTitle.title(for: String(repeating: "b", count: 80)) == String(repeating: "b", count: 80))
    }

    @Test func `a blank prompt is titled New Chat`() {
        #expect(ChatTitle.title(for: "  \n ") == "New Chat")
    }
}
