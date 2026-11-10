import AppKit
import DOTLauncherCore

/// What a script row does: fix permissions, ask for arguments, confirm,
/// run, and keep inline subtitles fresh.
final class ScriptActions {
    private let library: ScriptLibrary
    private let form: ScriptArgumentForm
    private let model: LauncherModel
    private let start: (ScriptCommand, [String]) -> Void
    /// ↩ on a row and in the arguments form.
    private let prompt = ConfirmationPrompt()
    /// Separate from ↩'s, so one press of each never adds up to a run.
    private let shortcutPrompt = ConfirmationPrompt()
    /// The form's values when it asked to confirm: changing one asks again.
    private var askedValues: [String]?
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
            prompt.reset()
            form.prepare(script)
            model.reset(to: .scriptArguments)
            return
        }
        if script.metadata.needsConfirmation {
            let text = "Press ↩ again to run \(script.metadata.title)"
            let model = model
            guard prompt.press(script.id, isShown: { model.notice == text }, show: { model.notice = text }, hide: { model.notice = nil })
            else { return }
        }
        start(script, [])
    }

    /// A script's global shortcut: what ↩ on its row does, except that a
    /// confirmation is asked with a HUD (press the shortcut again) and
    /// background scripts run without opening the panel.
    func runFromShortcut(_ script: ScriptCommand, comboText: String, showPanel: () -> Void, hud: HUDController) {
        let text = "Press \(comboText) again to run \(script.metadata.title)"
        let shortcutPrompt = shortcutPrompt
        let confirmed = {
            shortcutPrompt.press(
                script.id,
                isShown: { hud.currentText == text },
                show: { hud.show(text, isError: false, duration: shortcutPrompt.window + 1) },
                hide: { hud.hide() }
            )
        }
        switch ScriptShortcut.step(for: script, isConfirmed: confirmed()) {
        case .notExecutable:
            hud.show("Not executable. Select it in DOT and press ⌘⇧X.", isError: true)
        case .confirm:
            break // the prompt is up
        case .fillArguments:
            showPanel()
            prompt.reset()
            form.prepare(script)
            model.reset(to: .scriptArguments)
        case .runInPanel:
            showPanel()
            start(script, [])
        case .runInBackground:
            start(script, [])
        }
    }

    /// ↩ in the arguments form.
    func submitArguments() {
        // A held ↩ repeats: the repeat must not run the script or count as
        // the press that confirms it.
        guard NSApp.currentEvent?.isARepeat != true else { return }
        guard let script = form.script, let arguments = form.arguments() else { return }
        if script.metadata.needsConfirmation {
            // Confirms these values: editing one after the prompt asks again.
            let text = "Press ↩ again to run \(script.metadata.title)"
            let form = form
            let confirmed = prompt.press(
                script.id,
                isShown: { [weak self] in form.message == text && form.values == self?.askedValues },
                show: {
                    askedValues = form.values
                    form.message = text
                },
                hide: { form.message = nil }
            )
            guard confirmed else { return }
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
