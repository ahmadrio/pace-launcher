import DOTLauncherCore
import Foundation

/// What a script row does: fix permissions, ask for arguments, confirm,
/// run, and keep inline subtitles fresh.
final class ScriptActions {
    private let library: ScriptLibrary
    private let form: ScriptArgumentForm
    private let model: LauncherModel
    private let start: (ScriptCommand, [String]) -> Void
    private var confirmation = PressConfirmation()
    private var inline: [String: (text: String, updated: Date)] = [:]

    /// Called when an inline script produced a new subtitle.
    var onInlineUpdate: (() -> Void)?

    init(library: ScriptLibrary, form: ScriptArgumentForm, model: LauncherModel, start: @escaping (ScriptCommand, [String]) -> Void) {
        self.library = library
        self.form = form
        self.model = model
        self.start = start
    }

    func row(for script: ScriptCommand) -> LauncherResult {
        let subtitle: String = if !script.isExecutable {
            "Not executable — press ⌘⇧X to fix"
        } else if let text = inline[script.id]?.text {
            text
        } else {
            script.metadata.packageName ?? script.metadata.description ?? script.url.deletingLastPathComponent().lastPathComponent
        }
        var secondary: [SecondaryAction] = []
        if !script.isExecutable {
            secondary.append(SecondaryAction(title: "Make Executable", shortcut: .command("x", shift: true), action: .stay { [weak self] in
                self?.makeExecutable(script)
            }))
        }
        return LauncherResult(
            id: "script-row:" + script.id,
            title: script.metadata.title,
            subtitle: subtitle,
            icon: ScriptLibrary.icon(for: script),
            accessory: "Script",
            actionTitle: script.metadata.arguments.isEmpty ? "Run" : "Fill In",
            action: .stay { [weak self] in self?.activate(script) },
            secondaryActions: secondary
        )
    }

    /// ↩ on a script row.
    func activate(_ script: ScriptCommand) {
        guard script.isExecutable else {
            model.notice = "Not executable. Press ⌘⇧X to make it executable."
            return
        }
        guard script.metadata.arguments.isEmpty else {
            confirmation.reset()
            form.prepare(script)
            model.reset(to: .scriptArguments)
            return
        }
        guard confirmed(script) else {
            model.notice = "Press ↩ again to run \(script.metadata.title)"
            return
        }
        start(script, [])
    }

    /// ↩ in the arguments form.
    func submitArguments() {
        guard let script = form.script, let arguments = form.arguments() else { return }
        guard confirmed(script) else {
            form.message = "Press ↩ again to run \(script.metadata.title)"
            return
        }
        start(script, arguments)
    }

    /// Runs inline scripts whose subtitle is older than a minute (10 s
    /// timeout). Called when the launcher opens; nothing runs in the background otherwise.
    func refreshInline(now: Date = .now) {
        for script in library.scripts where script.metadata.mode == .inline && script.isExecutable && script.metadata.arguments.isEmpty {
            if let last = inline[script.id], now.timeIntervalSince(last.updated) < 60 { continue }
            inline[script.id] = (inline[script.id]?.text ?? "…", now)
            let run = ScriptRunner.run(script)
            run.onFinish = { [weak self] run in
                let line = run.output.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                self?.inline[script.id] = (run.succeeded ? line : "Failed: \(run.lastLine)", .now)
                self?.onInlineUpdate?()
            }
            Task {
                try? await Task.sleep(for: .seconds(10))
                run.stop()
            }
        }
    }

    private func confirmed(_ script: ScriptCommand) -> Bool {
        guard script.metadata.needsConfirmation else { return true }
        return confirmation.press(script.id, at: .now)
    }

    private func makeExecutable(_ script: ScriptCommand) {
        let path = script.url.path
        let current = (try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int) ?? 0o644
        do {
            try FileManager.default.setAttributes([.posixPermissions: current | 0o100], ofItemAtPath: path)
            model.notice = "\(script.metadata.title) is now executable"
        } catch {
            model.notice = "Could not change permissions: \(error.localizedDescription)"
        }
        library.reload()
    }
}
