import Foundation
import Testing
@testable import DOTLauncherCore

struct LegacyMigrationTests {
    private func temp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "legacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func `the old folder moves to the new name`() throws {
        let root = try temp()
        let old = root.appending(path: "DOT Launcher"), new = root.appending(path: "PACE Launcher")
        try FileManager.default.createDirectory(at: old.appending(path: "sub"), withIntermediateDirectories: true)
        try Data("a".utf8).write(to: old.appending(path: "a.txt"))
        try Data("b".utf8).write(to: old.appending(path: "sub/b.txt"))
        #expect(try LegacyMigration.moveFolder(from: old, to: new) == .moved)
        #expect(try String(contentsOf: new.appending(path: "a.txt"), encoding: .utf8) == "a")
        #expect(try String(contentsOf: new.appending(path: "sub/b.txt"), encoding: .utf8) == "b")
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test func `an existing new folder is left alone`() throws {
        let root = try temp()
        let old = root.appending(path: "DOT Launcher"), new = root.appending(path: "PACE Launcher")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appending(path: "x.txt"))
        try Data("new".utf8).write(to: new.appending(path: "x.txt"))
        #expect(try LegacyMigration.moveFolder(from: old, to: new) == .bothExist)
        #expect(try String(contentsOf: old.appending(path: "x.txt"), encoding: .utf8) == "old")
        #expect(try String(contentsOf: new.appending(path: "x.txt"), encoding: .utf8) == "new")
    }

    @Test func `nothing to move`() throws {
        let root = try temp()
        #expect(try LegacyMigration.moveFolder(from: root.appending(path: "DOT Launcher"), to: root.appending(path: "PACE Launcher")) == .nothingToMove)
    }

    @Test func `old settings carry over without test hooks`() {
        let old: [String: Any] = [
            "NSWindow Frame DOTNotesWindow": "f1", "NSWindow Frame DOTSettingsWindow": "f2",
            "syncEnabled": true, "extraScriptFolders": ["/x"],
            "DOTDataRootOverride": "/t", "DOTiCloudRootOverride": "/t", "DOTRatesURLOverride": "u", "DOTSystemCommandDryRun": true,
        ]
        let new = LegacyMigration.defaults(from: old)
        #expect(Set(new.keys) == ["NSWindow Frame PACENotesWindow", "NSWindow Frame PACESettingsWindow", "syncEnabled", "extraScriptFolders"])
        #expect(new["NSWindow Frame PACENotesWindow"] as? String == "f1")
        #expect(new["syncEnabled"] as? Bool == true)
        #expect(new["extraScriptFolders"] as? [String] == ["/x"])
    }
}
