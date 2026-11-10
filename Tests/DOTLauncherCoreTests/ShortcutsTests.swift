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
        #expect(ShortcutID.allCases.count == 2 + CommandShortcut.allCases.count + WindowAction.allCases.count)
        #expect(ShortcutID.window(.leftHalf).rawValue == "window.leftHalf")
        #expect(ShortcutID(rawValue: "window.nope") == nil)
        #expect(ShortcutID(rawValue: "nope") == nil)
    }

    @Test func `command shortcuts round-trip and have no default`() {
        #expect(ShortcutID.command(.translate).rawValue == "command.translate")
        #expect(ShortcutID(rawValue: "command.ai-chat") == .command(.aiChat))
        #expect(ShortcutID(rawValue: "command.nope") == nil)
        #expect(ShortcutID.command(.translate).defaultCombo == nil)
        #expect(ShortcutID.command(.translate).title == "Translate")
        #expect(ShortcutID.command(.aiChatHistory).title == "AI Chat History")
        #expect(CommandShortcut.allCases.map(\.title) == [
            "Translate", "AI Chat", "AI Chat History", "Open Notes", "Create Note",
            "Search Notes", "Search Snippets", "Create Snippet", "Settings", "Search Emoji",
            "Lock Screen", "Sleep", "Sleep Displays", "Start Screen Saver", "Toggle Dark Mode",
        ])
    }

    @Test func `commands are listed between the launcher group and windows`() {
        let groups = ShortcutID.allCases.map(\.group)
        let expected: [ShortcutID.Group] = [.launcher, .launcher]
            + Array(repeating: .commands, count: CommandShortcut.allCases.count)
            + Array(repeating: .window, count: WindowAction.allCases.count)
        #expect(groups == expected)
        #expect(ShortcutID.allCases[2] == .command(.translate))
    }

    @Test func `a command shortcut can be saved and resolved`() {
        let saved = Shortcuts.saved(combo("ctrl+opt+cmd+t"), for: .command(.translate), in: [:])
        #expect(saved == ["command.translate": "ctrl+opt+cmd+t"])
        #expect(Shortcuts.resolve(saved)[.command(.translate)] == combo("ctrl+opt+cmd+t"))
        #expect(Shortcuts.resolve([:])[.command(.translate)] == nil)
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
        let problem = Shortcuts.validate(combo("ctrl+space"), for: .launcher, current: Shortcuts.resolve([:]), system: [combo("ctrl+space")])
        #expect(problem == .usedByMacOS)
        #expect(problem?.message == "Used by macOS.")
    }

    @Test func `standard app shortcuts are refused`() {
        let current = Shortcuts.resolve([:])
        for string in ["cmd+c", "cmd+v", "cmd+shift+z", "cmd+q", "cmd+w", "cmd+tab", "cmd+comma", "cmd+shift+s"] {
            #expect(Shortcuts.validate(combo(string), for: .command(.translate), current: current, system: []) == .reservedByApps, "\(string)")
        }
        for string in ["cmd+shift+c", "cmd+opt+v", "ctrl+opt+v", "ctrl+cmd+c"] {
            #expect(Shortcuts.validate(combo(string), for: .command(.translate), current: current, system: []) == nil, "\(string)")
        }
        #expect(ShortcutProblem.reservedByApps.message == "Apps use this shortcut (copy, paste, …).")
    }

    @Test func `command space works once Spotlight's shortcut is off`() {
        // ⌘Space belongs to Spotlight, not to apps: with Spotlight's
        // shortcut turned off it is the classic launcher shortcut.
        let current = Shortcuts.resolve([:])
        #expect(Shortcuts.validate(combo("cmd+space"), for: .launcher, current: current, system: []) == nil)
        #expect(Shortcuts.validate(combo("cmd+space"), for: .launcher, current: current, system: [combo("cmd+space")]) == .usedByMacOS)
    }

    @Test func `swapping two combos releases both before registering`() {
        let a = combo("ctrl+opt+cmd+a"), b = combo("ctrl+opt+cmd+b")
        let plan = Shortcuts.registrationPlan(registered: [.launcher: a, .clipboardHistory: b], desired: [.launcher: b, .clipboardHistory: a])
        #expect(Set(plan.release) == [.launcher, .clipboardHistory])
        #expect(plan.register == [.launcher, .clipboardHistory])
    }

    @Test func `unchanged shortcuts are left alone`() {
        let a = combo("ctrl+opt+cmd+a"), b = combo("ctrl+opt+cmd+b"), c = combo("ctrl+opt+cmd+c")
        let plan = Shortcuts.registrationPlan(
            registered: [.launcher: a, .clipboardHistory: b, .window(.leftHalf): c],
            desired: [.launcher: a, .window(.rightHalf): c]
        )
        #expect(Set(plan.release) == [.clipboardHistory, .window(.leftHalf)])
        #expect(plan.register == [.window(.rightHalf)])
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

    @Test func `script shortcut ids round-trip`() {
        let id = ShortcutID.script("tools/deploy.sh")
        #expect(id.rawValue == "script.tools/deploy.sh")
        #expect(ShortcutID(rawValue: "script.tools/deploy.sh") == id)
        #expect(ShortcutID(rawValue: "script.") == nil)
        #expect(id.title == "deploy.sh")
        #expect(id.group == .scripts)
        #expect(id.defaultCombo == nil)
        #expect(!id.isRequired)
        #expect(!ShortcutID.allCases.contains { $0.group == .scripts })
    }

    @Test func `saved script shortcuts resolve`() {
        let resolved = Shortcuts.resolve(["script.a.sh": "ctrl+opt+1", "script.b.sh": "", "script.c.sh": "nonsense"])
        let scripts = resolved.filter { $0.key.group == .scripts }
        #expect(scripts == [.script("a.sh"): combo("ctrl+opt+1")])
    }

    @Test func `unusable saved combos fall back`() {
        #expect(Shortcuts.resolve(["launcher": "cmd+v"])[.launcher] == combo("opt+space"))
        #expect(Shortcuts.resolve(["window.leftHalf": "a"])[.window(.leftHalf)] == ShortcutID.window(.leftHalf).defaultCombo)
        #expect(Shortcuts.resolve(["command.translate": "cmd+1"])[.command(.translate)] == nil)
        #expect(Shortcuts.resolve(["script.a.sh": "cmd+c"])[.script("a.sh")] == nil)
    }

    @Test func `more standard app shortcuts are refused`() {
        for string in ["shift+cmd+t", "shift+cmd+n", "shift+cmd+v", "cmd+r", "cmd+b", "cmd+i", "cmd+l", "cmd+g",
                       "cmd+k", "cmd+d", "cmd+e", "cmd+u", "cmd+1", "cmd+9"] {
            #expect(Shortcuts.validate(combo(string), for: .command(.translate), current: [:], system: []) == .reservedByApps, "\(string)")
        }
        #expect(Shortcuts.validate(combo("ctrl+opt+cmd+1"), for: .command(.translate), current: [:], system: []) == nil)
        #expect(Shortcuts.validate(combo("shift+cmd+e"), for: .command(.translate), current: [:], system: []) == nil)
    }

    @Test func `a script shortcut conflicts like any other`() {
        let current: [ShortcutID: KeyCombo] = [.script("a.sh"): combo("ctrl+opt+1")]
        let problem = Shortcuts.validate(combo("ctrl+opt+1"), for: .launcher, current: current, system: [])
        #expect(problem == .usedBy(.script("a.sh")))
        #expect(problem?.message(naming: { _ in "Deploy" }) == "Already used by Deploy.")
        #expect(problem?.message == "Already used by a.sh.")
    }

    @Test func `registration plan covers script shortcuts`() {
        let removed = Shortcuts.registrationPlan(registered: [.script("a.sh"): combo("ctrl+opt+1")], desired: [:])
        #expect(removed.release == [.script("a.sh")])
        #expect(removed.register.isEmpty)
        let added = Shortcuts.registrationPlan(registered: [:], desired: [.script("b.sh"): combo("ctrl+opt+2"), .launcher: combo("opt+space")])
        #expect(added.register == [.launcher, .script("b.sh")])
    }

    @Test func `ids are ordered built-ins first, then scripts by key`() {
        let ids: [ShortcutID] = [.script("b.sh"), .window(.leftHalf), .script("a.sh"), .launcher, .launcher]
        #expect(Shortcuts.ordered(ids) == [.launcher, .window(.leftHalf), .script("a.sh"), .script("b.sh")])
    }

    @Test func `the lock and log out combos are refused`() {
        // DOT posts these to lock or log out; owning one would catch its own post.
        for string in ["ctrl+cmd+q", "shift+cmd+q"] {
            #expect(Shortcuts.validate(combo(string), for: .command(.lockScreen), current: [:], system: []) == .reservedByApps, "\(string)")
        }
        #expect(Shortcuts.resolve(["command.lock-screen": "ctrl+cmd+q"])[.command(.lockScreen)] == nil)
    }
}

