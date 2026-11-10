import Foundation
import Testing
@testable import DOTLauncherCore

struct SystemCommandTests {
    @Test func `system commands do what macOS does`() {
        #expect(SystemCommand.lockScreen.action == .keys(KeyCombo("ctrl+cmd+q")!))
        #expect(SystemCommand.logOut.action == .keys(KeyCombo("shift+cmd+q")!))
        #expect(SystemCommand.sleep.action == .process(path: "/usr/bin/pmset", arguments: ["sleepnow"]))
        #expect(SystemCommand.sleepDisplays.action == .process(path: "/usr/bin/pmset", arguments: ["displaysleepnow"]))
        #expect(SystemCommand.screenSaver.action == .openApp(path: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        #expect(SystemCommand.allCases.filter(\.needsConfirmation) == [.logOut, .restart, .shutDown, .emptyTrash])
        #expect(SystemCommand.allCases.filter(\.needsAccessibility) == [.lockScreen, .logOut])
        #expect(SystemCommand.allCases.map(\.title) == [
            "Lock Screen", "Sleep", "Sleep Displays", "Start Screen Saver", "Log Out",
            "Restart", "Shut Down", "Empty Trash", "Toggle Dark Mode",
        ])
        #expect(SystemCommand.logOut.confirmationNotice == "Press ↩ again to log out")
        #expect(SystemCommand.restart.confirmationNotice == "Press ↩ again to restart")
        #expect(SystemCommand.shutDown.confirmationNotice == "Press ↩ again to shut down")
        #expect(SystemCommand.emptyTrash.confirmationNotice == "Press ↩ again to empty the Trash")
        #expect(SystemCommand.toggleDarkMode.confirmationNotice == nil)
        guard case .appleScript(let restart, let restartTarget) = SystemCommand.restart.action,
              case .appleScript(let shutDown, _) = SystemCommand.shutDown.action,
              case .appleScript(let trash, let trashTarget) = SystemCommand.emptyTrash.action,
              case .appleScript(let dark, let darkTarget) = SystemCommand.toggleDarkMode.action
        else {
            Issue.record("the new commands are AppleScript")
            return
        }
        #expect(restart.contains("«event aevtrrst»") && restartTarget == "loginwindow")
        #expect(shutDown.contains("«event aevtrsdn»"))
        #expect(trash.contains("with timeout of 3600 seconds") && trash.contains(#"tell application "Finder" to empty trash"#) && trashTarget == "Finder")
        #expect(dark.contains("set dark mode to not dark mode") && darkTarget == "System Events")
        #expect(SystemCommand.lockScreen.aliases.contains("kunci"))
        #expect(SystemCommand.logOut.aliases.contains("keluar"))
        #expect(SystemCommand.restart.aliases.contains("reboot"))
        #expect(SystemCommand.shutDown.aliases.contains("matikan"))
        #expect(SystemCommand.emptyTrash.aliases.contains("kosongkan sampah"))
        #expect(SystemCommand.toggleDarkMode.aliases.contains("mode gelap"))
        // DOT's own theme lives in Settings; these words must not flip the Mac.
        #expect(!SystemCommand.toggleDarkMode.aliases.contains("tema"))
        #expect(!SystemCommand.toggleDarkMode.aliases.contains("appearance"))
        #expect(SystemCommand.allCases.allSatisfy { !$0.subtitle.isEmpty && !$0.symbol.isEmpty })
    }

    @Test func `system commands that can have shortcuts`() {
        let titles = CommandShortcut.allCases.map(\.title)
        #expect(Array(titles.suffix(6)) == ["Search Emoji", "Lock Screen", "Sleep", "Sleep Displays", "Start Screen Saver", "Toggle Dark Mode"])
        for confirming in ["Log Out", "Restart", "Shut Down", "Empty Trash"] {
            #expect(!titles.contains(confirming), "\(confirming)")
        }
        for command in [SystemCommand.lockScreen, .sleep, .sleepDisplays, .screenSaver, .toggleDarkMode] {
            #expect(CommandShortcut(rawValue: command.rawValue)?.title == command.title)
        }
    }

    @Test func `osascript endings are classified`() {
        #expect(AppleScriptEnd(status: 0, errorOutput: "") == .done)
        #expect(AppleScriptEnd(status: 1, errorOutput: "execution error: Not authorized to send Apple events to System Events. (-1743)") == .notPermitted)
        #expect(AppleScriptEnd(status: 1, errorOutput: "35:52: execution error: User canceled. (-128)") == .canceled)
        #expect(AppleScriptEnd(status: 1, errorOutput: "0:12: syntax error: Expected end of line. (-2741)\n") == .failed("0:12: syntax error: Expected end of line. (-2741)"))
        #expect(AppleScriptEnd(status: 1, errorOutput: "12:40: execution error: Finder got an error: AppleEvent timed out. (-1712)") == .timedOut)
        #expect(AppleScriptEnd(status: 1, errorOutput: "35:52: execution error: Finder got an error: Something. (-10000)\n") == .failed("Finder got an error: Something. (-10000)"))
        #expect(AppleScriptEnd(status: 9, errorOutput: "") == .failed("osascript exited with status 9"))
        let long = String(repeating: "x", count: 300)
        #expect(AppleScriptEnd(status: 1, errorOutput: long) == .failed(String(repeating: "x", count: 120)))
    }

    @Test func `the app explains its Apple Events`() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Info.plist")
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as? [String: Any]
        let text = info?["NSAppleEventsUsageDescription"] as? String
        #expect(text?.isEmpty == false)
    }
}
