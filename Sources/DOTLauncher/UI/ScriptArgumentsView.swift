import DOTLauncherCore
import Foundation
import Observation
import SwiftUI

/// The argument values being filled in for one script.
@Observable
final class ScriptArgumentForm {
    private(set) var script: ScriptCommand?
    /// Editing a value clears the message: a missing-value hint is out of
    /// date, and a confirmation prompt was for the old values.
    var values: [String] = [] {
        didSet { if values != oldValue { message = nil } }
    }
    /// Shown under the fields (missing values, confirmation prompt).
    var message: String?

    func prepare(_ script: ScriptCommand) {
        self.script = script
        values = script.metadata.arguments.map { argument in
            if case .dropdown(let items) = argument.kind { return items.first?.value ?? "" }
            return ""
        }
        message = nil
    }

    /// The argv to pass, or nil (with `message` set) when a required value
    /// is missing. Values are percent-encoded when the script asks for it.
    func arguments() -> [String]? {
        guard let script else { return nil }
        var result: [String] = []
        for (index, argument) in script.metadata.arguments.enumerated() {
            let value = values.indices.contains(index) ? values[index] : ""
            if value.isEmpty, !argument.optional {
                message = "“\(argument.placeholder.isEmpty ? "Argument \(index + 1)" : argument.placeholder)” is required"
                return nil
            }
            result.append(argument.percentEncoded
                ? (value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)
                : value)
        }
        return result
    }
}

struct ScriptArgumentsView: View {
    let form: ScriptArgumentForm
    let submit: () -> Void
    let cancel: () -> Void

    @FocusState private var focused: Int?

    var body: some View {
        @Bindable var form = form
        VStack(alignment: .leading, spacing: 12) {
            if let script = form.script {
                Text(script.metadata.title).font(.headline)
                ForEach(Array(script.metadata.arguments.enumerated()), id: \.offset) { index, argument in
                    field(for: argument, at: index, value: $form.values[index])
                }
                if let message = form.message {
                    Label(message, systemImage: "info.circle").foregroundStyle(.secondary).font(.system(size: 12))
                }
                Text("Tab moves between fields · ↩ runs · esc goes back")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // On the next turn: when the form first appears its fields are not
        // in the window yet, and the search field keeps the keyboard.
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            focused = 0
        }
        .onExitCommand(perform: cancel)
    }

    @ViewBuilder
    private func field(for argument: ScriptArgument, at index: Int, value: Binding<String>) -> some View {
        let label = argument.placeholder.isEmpty ? "Argument \(index + 1)" : argument.placeholder
        let title = argument.optional ? "\(label) (optional)" : label
        switch argument.kind {
        case .text:
            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
                .focused($focused, equals: index)
                .onSubmit(submit)
        case .password:
            SecureField(title, text: value)
                .textFieldStyle(.roundedBorder)
                .focused($focused, equals: index)
                .onSubmit(submit)
        case .dropdown(let items):
            Picker(title, selection: value) {
                ForEach(items, id: \.value) { item in
                    Text(item.title).tag(item.value)
                }
            }
            .focused($focused, equals: index)
        }
    }
}
