import SwiftUI

struct LauncherView: View {
    let model: LauncherModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                if model.mode == .clipboard {
                    Text("Clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: .capsule)
                }
                SearchField(model: model, placeholder: model.mode.placeholder)
            }
            .padding(.horizontal, 20)
            .frame(height: 60)

            Divider().opacity(0.5)

            ResultList(model: model)

            Divider().opacity(0.5)

            Footer(model: model)
        }
    }
}

private struct ResultList: View {
    let model: LauncherModel

    private var emptyMessage: String {
        switch (model.mode, model.query.isEmpty) {
        case (.root, true): "Start typing to search"
        case (.clipboard, true): "Nothing copied yet"
        case (_, false): "No results for “\(model.query)”"
        }
    }

    var body: some View {
        if model.results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: model.query.isEmpty ? "command" : "questionmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            ResultRow(result: result, isSelected: index == model.selectedIndex)
                                .id(result.id)
                                .contentShape(.rect)
                                .onTapGesture {
                                    model.select(index: index)
                                    model.performSelected()
                                }
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selectedIndex) { _, index in
                    guard model.results.indices.contains(index) else { return }
                    proxy.scrollTo(model.results[index].id)
                }
            }
        }
    }
}

private struct Footer: View {
    let model: LauncherModel

    var body: some View {
        HStack(spacing: 16) {
            Text(model.mode == .clipboard ? "Clipboard History" : "DOT Launcher").foregroundStyle(.tertiary)
            Spacer()
            if let selected = model.selected {
                KeyHint(key: "↩", label: selected.actionTitle)
            }
            KeyHint(key: "↑↓", label: "Navigate")
            KeyHint(key: "esc", label: model.mode == .root ? "Close" : "Back")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .frame(height: 36)
    }
}

private struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            Text(key)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: .rect(cornerRadius: 4))
        }
    }
}
