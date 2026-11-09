import Testing
@testable import DOTLauncherCore

struct KeyComboTests {
    @Test func `parses option space into Carbon key code and modifiers`() throws {
        let combo = try #require(KeyCombo("opt+space"))
        #expect(combo.keyCode == 49)
        #expect(combo.carbonModifiers == 2048)
    }

    @Test func `parses control option left arrow`() throws {
        let combo = try #require(KeyCombo("ctrl+opt+left"))
        #expect(combo.keyCode == 0x7B)
        #expect(combo.carbonModifiers == 4096 | 2048)
    }

    @Test(arguments: ["Option+Space", "alt+space", "OPT + SPACE"])
    func `accepts modifier aliases, any case and spaces`(input: String) {
        #expect(KeyCombo(input) == KeyCombo("opt+space"))
    }

    @Test(arguments: [
        ("opt+space", "⌥Space"),
        ("ctrl+opt+left", "⌃⌥←"),
        ("shift+opt+c", "⌥⇧C"),
        ("cmd+shift+opt+ctrl+k", "⌃⌥⇧⌘K"),
        ("ctrl+opt+return", "⌃⌥↩"),
    ])
    func `displays modifiers in canonical macOS order`(input: String, expected: String) throws {
        let combo = try #require(KeyCombo(input))
        #expect(combo.displayString == expected)
    }

    @Test(arguments: ["", "opt+banana", "ctrl+opt", "a+b", "opt+space+x"])
    func `rejects invalid combos`(input: String) {
        #expect(KeyCombo(input) == nil)
    }

    @Test func `detects a clash with a system shortcut`() throws {
        let spotlight = KeyCombo(keyCode: 49, carbonModifiers: 256)
        let system = [spotlight]

        #expect(try #require(KeyCombo("cmd+space")).conflicts(with: system))
        #expect(try #require(KeyCombo("opt+space")).conflicts(with: system) == false)
    }
}
