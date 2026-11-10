import Foundation
import Testing
@testable import PACELauncherCore

struct ThemeTests {
    @Test func `standard matches the stage 2 look`() {
        let theme = ThemeSettings()
        #expect(theme.preset == .standard)
        #expect(theme.accent == nil)          // system accent color
        #expect(theme.glassTint == 0.6)
        #expect(theme.appearance == .system)
    }

    @Test func `presets fill every value`() {
        var theme = ThemeSettings()
        theme.apply(.midnight)
        #expect(theme.preset == .midnight)
        #expect(theme.accent != nil)
        #expect(theme.appearance == .dark)

        theme.apply(.paper)
        #expect(theme.preset == .paper)
        #expect(theme.appearance == .light)
    }

    @Test func `changing a value makes the theme custom`() {
        var theme = ThemeSettings(preset: .sunset)
        theme.setGlassTint(0.3)
        #expect(theme.preset == .custom)
        #expect(theme.glassTint == 0.3)

        var other = ThemeSettings(preset: .graphite)
        other.setAccent(RGB(hex: "#112233")!)
        #expect(other.preset == .custom)
        #expect(other.accent?.hex == "#112233")
    }

    @Test func `tint is clamped`() {
        var theme = ThemeSettings()
        theme.setGlassTint(1.5)
        #expect(theme.glassTint == 0.9)
        theme.setGlassTint(-1)
        #expect(theme.glassTint == 0)
    }

    @Test func `hex round-trips`() {
        #expect(RGB(hex: "#FF8800")?.hex == "#FF8800")
        #expect(RGB(hex: "ff8800")?.hex == "#FF8800")
        #expect(RGB(hex: "zz") == nil)
    }

    @Test func `decodes old settings without a theme`() throws {
        let data = try JSONDecoder().decode(SettingsData.self, from: Data("{}".utf8))
        #expect(data.theme == ThemeSettings())
    }

    @Test func `a partial theme keeps the other settings`() throws {
        let json = #"{"showMenuBarIcon": false, "theme": {"preset": "midnight"}}"#
        let data = try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8))
        #expect(data.showMenuBarIcon == false)
        #expect(data.theme.preset == .midnight)
    }

    @Test func `round-trips through JSON`() throws {
        var theme = ThemeSettings(preset: .paper)
        theme.setAppearance(.dark)
        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: JSONEncoder().encode(theme))
        #expect(decoded == theme)
    }
}
