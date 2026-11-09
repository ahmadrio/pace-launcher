import SwiftUI

struct LauncherView: View {
    let model: LauncherModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                SearchField(model: model, placeholder: "Search apps, calculate, or run a command…")
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

    var body: some View {
        if model.results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: model.query.isEmpty ? "command" : "questionmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(model.query.isEmpty ? "Start typing to search" : "No results for “\(model.query)”")
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
            if let toast = model.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("DOT Launcher").foregroundStyle(.tertiary)
            }
            Spacer()
            if let selected = model.selected {
                KeyHint(key: "↩", label: selected.actionTitle)
            }
            KeyHint(key: "↑↓", label: "Navigate")
            KeyHint(key: "esc", label: "Close")
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
