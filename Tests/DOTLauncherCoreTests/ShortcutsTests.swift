import Testing
@testable import DOTLauncherCore

private func combo(_ string: String) -> KeyCombo { KeyCombo(string)! }

struct ShortcutsTests {
    @Test func `string form round-trips for every known key`() {
        for string in ["opt+space", "ctrl+opt+left", "shift+opt+c", "cmd+shift+f5", "ctrl+opt+return", "ctrl+opt+delete", "ctrl+cmd+;", "ctrl+opt+cmd+l", "f12"] {
            let parsed = combo(string)
            #expect(KeyCombo(parsed.stringValue) == parsed, "\(string) → \(parsed.stringValue)")
        }
        #expect(combo("cmd+ctrl+opt+shift+k").stringValue == "ctrl+opt+shift+cmd+k")
    }

    @Test func `defaults match the existing shortcuts`() {
        #expect(ShortcutID.launcher.defaultCombo == combo("opt+space"))
        #expect(ShortcutID.clipboardHistory.defaultCombo == combo("shift+opt+c"))
        #expect(ShortcutID.window(.leftHalf).defaultCombo == combo("ctrl+opt+left"))
        #expect(ShortcutID.window(.almostMaximize).defaultCombo == nil)
        #expect(ShortcutID.launcher.title == "Open DOT Launcher")
        #expect(ShortcutID.window(.leftHalf).title == "Left Half")
    }

    @Test func `ids round-trip through their raw values`() {
        for id in ShortcutID.allCases {
            #expect(ShortcutID(rawValue: id.rawValue) == id)
        }
        #expect(ShortcutID.allCases.count == 2 + WindowAction.allCases.count)
        #expect(ShortcutID.window(.leftHalf).rawValue == "window.leftHalf")
        #expect(ShortcutID(rawValue: "window.nope") == nil)
        #expect(ShortcutID(rawValue: "nope") == nil)
    }

    @Test func `resolve uses defaults, saved combos, and empty means none`() {
        let resolved = Shortcuts.resolve(["window.leftHalf": "ctrl+cmd+left", "clipboardHistory": ""])
        #expect(resolved[.window(.leftHalf)] == combo("ctrl+cmd+left"))
        #expect(resolved[.clipboardHistory] == nil)
        #expect(resolved[.launcher] == combo("opt+space"))
        #expect(resolved[.window(.rightHalf)] == combo("ctrl+opt+right"))
        #expect(resolved[.window(.almostMaximize)] == nil)
    }

    @Test func `invalid saved strings fall back to the default`() {
        #expect(Shortcuts.resolve(["window.leftHalf": "ctrl+banana"])[.window(.leftHalf)] == combo("ctrl+opt+left"))
    }

    @Test func `the launcher shortcut cannot be removed`() {
        let current = Shortcuts.resolve([:])
        #expect(Shortcuts.validate(nil, for: .launcher, current: current, system: []) == .required)
        #expect(Shortcuts.validate(nil, for: .clipboardHistory, current: current, system: []) == nil)
        #expect(Shortcuts.resolve(["launcher": ""])[.launcher] == combo("opt+space"))
        #expect(ShortcutProblem.required.message == "Open DOT Launcher needs a shortcut.")
    }

    @Test func `needs command, control or option unless it is a function key`() {
        let current = Shortcuts.resolve([:])
        #expect(Shortcuts.validate(combo("shift+a"), for: .clipboardHistory, current: current, system: []) == .needsModifier)
        #expect(Shortcuts.validate(combo("a"), for: .clipboardHistory, current: current, system: []) == .needsModifier)
        #expect(Shortcuts.validate(combo("f5"), for: .clipboardHistory, current: current, system: []) == nil)
        #expect(Shortcuts.validate(combo("ctrl+a"), for: .clipboardHistory, current: current, system: []) == nil)
        #expect(ShortcutProblem.needsModifier.message == "Add ⌘, ⌃ or ⌥.")
    }

    @Test func `keys outside the table are refused`() {
        let keypadZero = KeyCombo(keyCode: 82, carbonModifiers: KeyCombo.option)
        #expect(!keypadZero.isKnownKey)
        #expect(Shortcuts.validate(keypadZero, for: .clipboardHistory, current: Shortcuts.resolve([:]), system: []) == .unknownKey)
        #expect(ShortcutProblem.unknownKey.message == "This key can't be used.")
    }

    @Test func `a combo used by another DOT shortcut names it`() {
        let problem = Shortcuts.validate(combo("ctrl+opt+left"), for: .window(.almostMaximize), current: Shortcuts.resolve([:]), system: [])
        #expect(problem == .usedBy(.window(.leftHalf)))
        #expect(problem?.message == "Already used by Left Half.")
    }

    @Test func `recording the same combo again for the same shortcut is fine`() {
        #expect(Shortcuts.validate(combo("ctrl+opt+left"), for: .window(.leftHalf), current: Shortcuts.resolve([:]), system: []) == nil)
    }

    @Test func `a combo used by macOS is refused`() {
        let problem = Shortcuts.validate(combo("cmd+space"), for: .launcher, current: Shortcuts.resolve([:]), system: [combo("cmd+space")])
        #expect(problem == .usedByMacOS)
        #expect(problem?.message == "Used by macOS.")
    }

    @Test func `only default combos are gated by Maccy and Rectangle`() {
        #expect(Shortcuts.followsOtherAppHabit(.clipboardHistory, combo("shift+opt+c")))
        #expect(!Shortcuts.followsOtherAppHabit(.clipboardHistory, combo("ctrl+opt+v")))
        #expect(Shortcuts.followsOtherAppHabit(.window(.leftHalf), combo("ctrl+opt+left")))
        #expect(!Shortcuts.followsOtherAppHabit(.launcher, combo("opt+space")))
    }

    @Test func `saving the default removes the override and saving none stores empty`() {
        let saved = ["launcher": "ctrl+opt+cmd+l", "window.leftHalf": "ctrl+cmd+left"]
        #expect(Shortcuts.saved(combo("opt+space"), for: .launcher, in: saved) == ["window.leftHalf": "ctrl+cmd+left"])
        #expect(Shortcuts.saved(nil, for: .clipboardHistory, in: [:]) == ["clipboardHistory": ""])
        #expect(Shortcuts.saved(combo("ctrl+opt+m"), for: .window(.almostMaximize), in: [:]) == ["window.almostMaximize": "ctrl+opt+m"])
        #expect(Shortcuts.saved(nil, for: .window(.almostMaximize), in: ["window.almostMaximize": "ctrl+opt+m"]) == [:])
    }
}
