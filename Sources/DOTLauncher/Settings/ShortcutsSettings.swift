import AppKit
import DOTLauncherCore
import Observation
import SwiftUI

/// Records a new global shortcut from the next key press in Settings.
/// DOT's own hotkeys are paused meanwhile, so a combo DOT already uses
/// (⌥Space) reaches the recorder instead of opening the launcher.
@Observable
final class ShortcutRecorder {
    private(set) var recording: ShortcutID?
    /// The last refusal per shortcut, shown under its row.
    private(set) var problems: [ShortcutID: String] = [:]

    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let hotKeys: HotKeyCenter
    /// true while recording: the app releases or re-applies its hotkeys.
    @ObservationIgnored private let pause: (Bool) -> Void
    @ObservationIgnored private var monitor: Any?

    init(settings: SettingsStore, hotKeys: HotKeyCenter, pause: @escaping (Bool) -> Void) {
        self.settings = settings
        self.hotKeys = hotKeys
        self.pause = pause
    }

    var current: [ShortcutID: KeyCombo] { Shortcuts.resolve(settings.data.shortcuts) }

    func start(_ id: ShortcutID) {
        stop()
        problems[id] = nil
        recording = id
        pause(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording != nil else { return event }
            self.handle(event)
            return nil
        }
    }

    /// Ends recording (if any) and re-applies the hotkeys.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording != nil else { return }
        recording = nil
        pause(false)
    }

    func reset(_ id: ShortcutID) {
        stop()
        choose(id.defaultCombo, for: id)
    }

    private func handle(_ event: NSEvent) {
        guard let id = recording else { return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch (event.keyCode, flags.isEmpty) {
        case (53, true):  // Esc cancels
            stop()
        case (51, true):  // ⌫ removes the shortcut
            if choose(nil, for: id) { stop() }
        default:
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= KeyCombo.command }
            if flags.contains(.shift) { modifiers |= KeyCombo.shift }
            if flags.contains(.option) { modifiers |= KeyCombo.option }
            if flags.contains(.control) { modifiers |= KeyCombo.control }
            if choose(KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers), for: id) { stop() }
        }
    }

    /// Saves `combo` for `id` unless it is refused. Returns true when saved.
    @discardableResult
    private func choose(_ combo: KeyCombo?, for id: ShortcutID) -> Bool {
        if let problem = Shortcuts.validate(combo, for: id, current: current, system: HotKeyCenter.enabledSystemShortcuts()) {
            problems[id] = problem.message
            return false
        }
        problems[id] = nil
        settings.data.shortcuts = Shortcuts.saved(combo, for: id, in: settings.data.shortcuts)
        return true
    }
}

struct ShortcutsSettings: View {
    let recorder: ShortcutRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Click a shortcut, then press the new keys. Esc cancels, ⌫ removes it. Clipboard and window shortcuts left at their defaults turn off while Maccy or Rectangle runs.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(ShortcutID.allCases, id: \.rawValue) { id in
                    ShortcutRow(id: id, recorder: recorder)
                }
            }
        }
        .onDisappear { recorder.stop() }
    }
}

private struct ShortcutRow: View {
    let id: ShortcutID
    let recorder: ShortcutRecorder

    private var combo: KeyCombo? { recorder.current[id] }
    private var isRecording: Bool { recorder.recording == id }

    private var label: String {
        if isRecording { return "Press a shortcut…" }
        return combo?.displayString ?? "None"
    }

    /// Why a saved shortcut is not working right now, if it is not.
    private var status: String? {
        guard !isRecording, recorder.recording == nil, combo != nil else { return nil }
        switch recorder.hotKeys.status(of: id.title) {
        case .unavailable: return "Couldn't register: another app uses it"
        case .disabled(let reason): return reason.prefix(1).uppercased() + reason.dropFirst()
        case .registered, nil: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(id.title)
                Spacer()
                Button {
                    if isRecording { recorder.stop() } else { recorder.start(id) }
                } label: {
                    Text(label)
                        .frame(minWidth: 130)
                }
                .accessibilityIdentifier("shortcut-" + id.rawValue)
                if combo != id.defaultCombo, !isRecording {
                    Button("Reset") { recorder.reset(id) }
                        .accessibilityIdentifier("reset-" + id.rawValue)
                }
            }
            if let problem = recorder.problems[id] {
                Text(problem)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            } else if let status {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
    }
}
