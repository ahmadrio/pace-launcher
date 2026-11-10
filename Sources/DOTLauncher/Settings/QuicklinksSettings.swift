import AppKit
import DOTLauncherCore
import Observation
import SwiftUI

/// The add/edit form of Settings › Quicklinks. Saving checks the draft
/// with `Quicklinks.problem` and writes `settings.data.quicklinks`.
@Observable
final class QuicklinkEditor {
    /// The quicklink being added or edited; nil when the form is closed.
    var draft: Quicklink?
    /// The keyword field ("" = none).
    var keywordText = ""
    private(set) var message: String?

    @ObservationIgnored private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func startAdding() {
        draft = Quicklink(name: "", keyword: nil, url: "")
        keywordText = ""
        message = nil
    }

    func edit(_ link: Quicklink) {
        draft = link
        keywordText = link.keyword ?? ""
        message = nil
    }

    func save() {
        guard var link = draft else { return }
        link.name = link.name.trimmingCharacters(in: .whitespaces)
        link.url = link.url.trimmingCharacters(in: .whitespaces)
        let keyword = keywordText.trimmingCharacters(in: .whitespaces)
        link.keyword = keyword.isEmpty ? nil : keyword
        if let problem = Quicklinks.problem(with: link, existing: settings.data.quicklinks) {
            message = problem
            return
        }
        if let index = settings.data.quicklinks.firstIndex(where: { $0.id == link.id }) {
            settings.data.quicklinks[index] = link
        } else {
            settings.data.quicklinks.append(link)
        }
        draft = nil
        message = nil
    }

    func cancel() {
        draft = nil
        message = nil
    }

    /// No confirmation: a quicklink is quick to make again.
    func delete(_ link: Quicklink) {
        settings.data.quicklinks.removeAll { $0.id == link.id }
        if draft?.id == link.id { cancel() }
    }
}

struct QuicklinksSettings: View {
    let settings: SettingsStore
    let editor: QuicklinkEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use {query} where the text you type should go. Type the keyword, a space and your text in the launcher.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.data.quicklinks.isEmpty {
                Text("No quicklinks yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(settings.data.quicklinks) { link in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(link.name)
                            if let keyword = link.keyword {
                                Text(keyword)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: .rect(cornerRadius: 4))
                            }
                        }
                        Text(link.url)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Edit") { editor.edit(link) }
                        .accessibilityIdentifier("quicklink-edit-" + link.id.uuidString)
                    Button("Delete") { editor.delete(link) }
                        .accessibilityIdentifier("quicklink-delete-" + link.id.uuidString)
                }
            }

            if editor.draft != nil {
                form
            } else {
                Button("Add Quicklink") { editor.startAdding() }
                    .accessibilityIdentifier("quicklink-add")
            }
        }
    }

    /// Installed browsers, plus the saved one when it is not installed here.
    private var browserChoices: [(name: String, bundleID: String)] {
        var choices = QuicklinkOpener.browsers()
        if let saved = editor.draft?.browser,
           !choices.contains(where: { $0.bundleID.caseInsensitiveCompare(saved) == .orderedSame }) {
            let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: saved) != nil
            choices.append((installed ? QuicklinkOpener.name(of: saved) : BrowserNames.displayName(for: saved) + " (not found)", saved))
        }
        return choices
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(settings.data.quicklinks.contains { $0.id == editor.draft?.id } ? "Edit Quicklink" : "New Quicklink")
                .font(.headline)
            TextField("Name", text: Binding(get: { editor.draft?.name ?? "" }, set: { editor.draft?.name = $0 }))
                .accessibilityIdentifier("quicklink-name")
            TextField("Keyword (optional)", text: Binding(get: { editor.keywordText }, set: { editor.keywordText = $0 }))
                .accessibilityIdentifier("quicklink-keyword")
            TextField("URL, such as https://example.com/search?q={query}", text: Binding(get: { editor.draft?.url ?? "" }, set: { editor.draft?.url = $0 }))
                .accessibilityIdentifier("quicklink-url")
            Picker("Open with", selection: Binding(get: { editor.draft?.browser ?? "" }, set: { editor.draft?.browser = $0.isEmpty ? nil : $0 })) {
                Text("Default browser").tag("")
                ForEach(browserChoices, id: \.bundleID) { browser in
                    // Tag with the saved spelling when only the case differs, so it stays selected.
                    Text(browser.name).tag(browser.bundleID.caseInsensitiveCompare(editor.draft?.browser ?? "") == .orderedSame
                        ? (editor.draft?.browser ?? browser.bundleID) : browser.bundleID)
                }
            }
            .accessibilityIdentifier("quicklink-browser")
            if let message = editor.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { editor.cancel() }
                Button("Save") { editor.save() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("quicklink-save")
            }
        }
    }
}
