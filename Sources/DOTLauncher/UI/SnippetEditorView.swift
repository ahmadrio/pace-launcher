import DOTLauncherCore
import Observation
import SwiftUI

/// The fields being edited, plus the snippet they came from (nil = new).
@Observable
final class SnippetDraft {
    let original: Snippet?
    var name: String
    var keyword: String
    var content: String
    /// Set after the first click on Delete.
    var deleteArmed = false

    init(_ snippet: Snippet?) {
        original = snippet
        name = snippet?.name ?? ""
        keyword = snippet?.keyword ?? ""
        content = snippet?.content ?? ""
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The snippet to store: same id and creation date when editing.
    func snippet(now: Date = .now) -> Snippet {
        let keyword = keyword.trimmingCharacters(in: .whitespaces)
        return Snippet(
            id: original?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            keyword: keyword.isEmpty ? nil : keyword,
            content: content,
            createdAt: original?.createdAt ?? now,
            updatedAt: now
        )
    }
}

struct SnippetEditorView: View {
    let draft: SnippetDraft
    let save: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    private enum Field { case name, keyword, content }
    @FocusState private var focus: Field?

    var body: some View {
        @Bindable var draft = draft
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Name") {
                TextField("Office address", text: $draft.name)
                    .focused($focus, equals: .name)
            }
            LabeledContent("Keyword") {
                TextField(";addr (optional)", text: $draft.keyword)
                    .focused($focus, equals: .keyword)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Content").foregroundStyle(.secondary)
                TextEditor(text: $draft.content)
                    .font(.system(size: 13))
                    .focused($focus, equals: .content)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.quaternary, in: .rect(cornerRadius: 6))
                Text("Placeholders: {date} {time} {datetime} {clipboard}")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            HStack {
                if draft.original != nil {
                    Button(draft.deleteArmed ? "Click again to delete" : "Delete", role: .destructive, action: delete)
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!draft.canSave)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 340)
        .onAppear { focus = .name }
    }
}
