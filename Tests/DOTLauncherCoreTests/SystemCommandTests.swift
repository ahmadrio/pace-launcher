import Testing
@testable import DOTLauncherCore

struct SystemCommandTests {
    @Test func `system commands do what macOS does`() {
        #expect(SystemCommand.lockScreen.action == .keys(KeyCombo("ctrl+cmd+q")!))
        #expect(SystemCommand.logOut.action == .keys(KeyCombo("shift+cmd+q")!))
        #expect(SystemCommand.sleep.action == .process(path: "/usr/bin/pmset", arguments: ["sleepnow"]))
        #expect(SystemCommand.sleepDisplays.action == .process(path: "/usr/bin/pmset", arguments: ["displaysleepnow"]))
        #expect(SystemCommand.screenSaver.action == .openApp(path: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        #expect(SystemCommand.allCases.filter(\.needsConfirmation) == [.logOut])
        #expect(SystemCommand.allCases.filter(\.needsAccessibility) == [.lockScreen, .logOut])
        #expect(SystemCommand.allCases.map(\.title) == ["Lock Screen", "Sleep", "Sleep Displays", "Start Screen Saver", "Log Out"])
        #expect(SystemCommand.lockScreen.aliases.contains("kunci"))
        #expect(SystemCommand.logOut.aliases.contains("keluar"))
        #expect(SystemCommand.allCases.allSatisfy { !$0.subtitle.isEmpty && !$0.symbol.isEmpty })
    }

    @Test func `system commands that can have shortcuts`() {
        let titles = CommandShortcut.allCases.map(\.title)
        #expect(Array(titles.suffix(5)) == ["Search Emoji", "Lock Screen", "Sleep", "Sleep Displays", "Start Screen Saver"])
        #expect(!titles.contains("Log Out"))
        for command in [SystemCommand.lockScreen, .sleep, .sleepDisplays, .screenSaver] {
            #expect(CommandShortcut(rawValue: command.rawValue)?.title == command.title)
        }
    }
}
