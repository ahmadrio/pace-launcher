import DOTLauncherCore
import SwiftUI

struct ChatView: View {
    let chat: AIChatController

    var body: some View {
        if chat.messages.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(chat.unavailableReason ?? "Ask anything. Answers come from Apple's on-device model.\nQuestions in Indonesian are translated automatically.\nPress ⌘Y for saved chats.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(chat.messages) { message in
                            MessageView(message: message, showOriginal: chat.showOriginal)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                // The view is rebuilt each time AI mode opens, often after
                // a message was already sent: start at the latest message.
                .defaultScrollAnchor(.bottom)
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: chat.messages.last?.text) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: chat.messages.count) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

private struct MessageView: View {
    let message: ChatMessage
    let showOriginal: Bool

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: .rect(cornerRadius: 12))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                status
                MarkdownText(markdown: displayed)
                    .opacity(message.isBridged ? 0.55 : 1)
            }
        }
    }

    private var displayed: String {
        showOriginal ? (message.original ?? message.text) : message.text
    }

    @ViewBuilder private var status: some View {
        switch message.phase {
        case .streaming where message.text.isEmpty:
            Label("Thinking…", systemImage: "sparkles").foregroundStyle(.secondary).font(.system(size: 12))
        case .streaming where message.isBridged:
            Label("English draft", systemImage: "character.bubble").foregroundStyle(.secondary).font(.system(size: 12))
        case .translating:
            Label("Translating…", systemImage: "character.book.closed").foregroundStyle(.secondary).font(.system(size: 12))
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.system(size: 13))
        default:
            if showOriginal, message.original != nil {
                Label("Original (English)", systemImage: "character.bubble").foregroundStyle(.secondary).font(.system(size: 12))
            }
        }
    }
}

/// Inline Markdown for prose, monospaced boxes for fenced code blocks.
private struct MarkdownText: View {
    let markdown: String

    private enum Block: Hashable {
        case prose(String)
        case code(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .prose(let text):
                    Text(attributed(text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let code):
                    Text(code)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    /// Fenced blocks become code boxes; inline code stays in the prose,
    /// where the Markdown renderer shows it monospaced.
    private var blocks: [Block] {
        var blocks: [Block] = []
        var prose = ""
        for segment in MarkdownSegments.split(markdown) {
            switch segment {
            case .code(let text) where text.hasPrefix("```"):
                if !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.prose(prose.trimmingCharacters(in: .newlines)))
                }
                prose = ""
                blocks.append(.code(Self.stripFence(text)))
            case .prose(let text), .code(let text):
                prose += text
            }
        }
        if !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.prose(prose.trimmingCharacters(in: .newlines)))
        }
        return blocks
    }

    private func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    /// Drops the ``` lines (and the language tag) around a code block.
    private static func stripFence(_ block: String) -> String {
        var lines = block.components(separatedBy: "\n")
        if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
        if lines.last?.hasPrefix("```") == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
