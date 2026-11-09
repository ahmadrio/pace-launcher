import DOTLauncherCore
import SwiftUI

struct NotesView: View {
    let model: NotesModel
    let onTextView: (NSTextView) -> Void

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    model.showingSwitcher.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("All notes (⌘P)")
                .popover(isPresented: $model.showingSwitcher, arrowEdge: .bottom) {
                    NoteSwitcher(model: model)
                }
                Button {
                    model.createNew()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New note (⌘N)")
                Button {
                    model.requestTrashCurrent()
                } label: {
                    Image(systemName: model.deleteArmed ? "trash.fill" : "trash")
                        .foregroundStyle(model.deleteArmed ? .red : .secondary)
                }
                .help(model.deleteArmed ? "Click or press ⌃X again to move to Trash" : "Delete note (⌃X)")
            }
            .buttonStyle(.borderless)
            // Leave room for the window's close button in the title bar.
            .padding(.leading, 76)
            .padding(.trailing, 12)
            .frame(height: 30)

            if model.deleteArmed {
                Text("Press ⌃X again to move this note to the Trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Divider()

            MarkdownTextView(text: $model.body, onCreate: onTextView)
        }
        // The header sits in the (transparent) title bar, beside the
        // window buttons, instead of below an empty title bar row.
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// The ⌘P list: every note, filtered by title or content.
/// (The query lives in the model: on this SDK `@State` is a macro whose
/// plugin the Command Line Tools do not ship.)
private struct NoteSwitcher: View {
    let model: NotesModel

    private var matches: [NoteSummary] {
        let query = model.switcherQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.summaries }
        return model.summaries.filter {
            $0.title.localizedCaseInsensitiveContains(query) || model.body(of: $0.id).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search notes", text: $model.switcherQuery)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(matches) { note in
                        Button {
                            model.showingSwitcher = false
                            model.open(note.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(note.title).lineLimit(1)
                                Text(note.preview).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(note.id == model.currentID ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280, height: 320)
    }
}
