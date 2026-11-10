import Foundation
import Testing
@testable import DOTLauncherCore

struct SettingsFileTests {
    @Test func `missing file gives defaults`() {
        let folder = TemporaryFolder()
        #expect(SettingsFile(url: folder.url.appending(path: "settings.json")).load() == SettingsData())
    }

    @Test func `save then load round-trips`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let file = SettingsFile(url: folder.url.appending(path: "settings.json"))
        var data = SettingsData()
        data.showMenuBarIcon = false
        data.autoExpandExcludedBundleIDs = ["com.apple.Terminal"]
        data.includeClipboardInBackup = false

        try file.save(data)

        #expect(file.load() == data)
    }

    @Test func `settings without shortcuts still load`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("settings.json", #"{"showMenuBarIcon": false}"#)
        #expect(SettingsFile(url: folder.url.appending(path: "settings.json")).load().shortcuts == [:])
    }

    @Test func `retention defaults to forever and round-trips`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("settings.json", #"{"showMenuBarIcon": false}"#)
        let file = SettingsFile(url: folder.url.appending(path: "settings.json"))
        #expect(file.load().clipboardRetention == .forever)

        var data = file.load()
        data.clipboardRetention = .month
        try file.save(data)
        #expect(file.load().clipboardRetention == .month)
    }

    @Test func `shortcuts round-trip`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let file = SettingsFile(url: folder.url.appending(path: "settings.json"))
        var data = SettingsData()
        data.shortcuts = ["launcher": "ctrl+opt+cmd+l", "clipboardHistory": ""]
        try file.save(data)
        #expect(file.load().shortcuts == data.shortcuts)
    }

    @Test func `corrupt file gives defaults`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("settings.json", "{ not json")
        #expect(SettingsFile(url: folder.url.appending(path: "settings.json")).load() == SettingsData())
    }

    @Test func `missing keys keep their defaults`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("settings.json", #"{"showMenuBarIcon": false}"#)

        let data = SettingsFile(url: folder.url.appending(path: "settings.json")).load()

        #expect(data.showMenuBarIcon == false)
        #expect(data.autoExpandEnabled == true)
        #expect(data.includeClipboardInBackup == true)
    }

    @Test func `unknown keys are ignored`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("settings.json", #"{"showMenuBarIcon": false, "futureOption": 42}"#)
        #expect(SettingsFile(url: folder.url.appending(path: "settings.json")).load().showMenuBarIcon == false)
    }

    @Test func `does not write over settings iCloud has not downloaded`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write(".settings.json.icloud", "stub")
        let file = SettingsFile(url: folder.url.appending(path: "settings.json"))

        #expect(file.isWaitingForDownload)
        #expect(throws: (any Error).self) { try file.save(SettingsData()) }
        #expect(!FileManager.default.fileExists(atPath: file.url.path))

        try folder.write("settings.json", "{}")
        #expect(!file.isWaitingForDownload)
    }

    @Test func `quicklinks load leniently`() throws {
        func decode(_ json: String) throws -> SettingsData {
            try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8))
        }
        #expect(try decode("{}").quicklinks == Quicklink.defaults)
        #expect(try decode(#"{"quicklinks": []}"#).quicklinks.isEmpty)
        let mixed = try decode(#"{"quicklinks": [{"id": "6F1C2A3B-0000-4000-8000-000000000001", "name": "A", "url": "https://a.test"}, {"name": 3}], "showMenuBarIcon": false}"#)
        #expect(mixed.quicklinks.map(\.name) == ["A"])
        #expect(mixed.quicklinks.first?.keyword == nil)
        #expect(!mixed.showMenuBarIcon)
        #expect(try decode(#"{"quicklinks": "oops", "showMenuBarIcon": false}"#).quicklinks == Quicklink.defaults)

        var data = SettingsData()
        data.quicklinks = [Quicklink(name: "Wiki", keyword: "wk", url: "https://w.test/{query}")]
        let copy = try JSONDecoder().decode(SettingsData.self, from: JSONEncoder().encode(data))
        #expect(copy.quicklinks == data.quicklinks)
    }

    @Test func `skin tone loads leniently`() throws {
        func decode(_ json: String) throws -> SettingsData {
            try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"emojiSkinTone": "medium"}"#).emojiSkinTone == .medium)
        let unknown = try decode(#"{"emojiSkinTone": "purple", "showMenuBarIcon": false}"#)
        #expect(unknown.emojiSkinTone == .default)
        #expect(!unknown.showMenuBarIcon)
        #expect(try decode(#"{"emojiSkinTone": 3}"#).emojiSkinTone == .default)
        #expect(try decode(#"{"emojiSkinTone": "none"}"#).emojiSkinTone == .default)
        #expect(try decode("{}").emojiSkinTone == .default)
        let written = String(decoding: try JSONEncoder().encode(SettingsData()), as: UTF8.self)
        #expect(written.contains(#""emojiSkinTone":"none""#))
        var data = SettingsData()
        data.emojiSkinTone = .mediumDark
        let copy = try JSONDecoder().decode(SettingsData.self, from: JSONEncoder().encode(data))
        #expect(copy.emojiSkinTone == .mediumDark)
    }

    @Test func `quicklinks without or with duplicate ids load`() throws {
        func decode(_ json: String) throws -> SettingsData {
            try JSONDecoder().decode(SettingsData.self, from: Data(json.utf8))
        }
        let handWritten = #"{"quicklinks": [{"name": "Wiki", "url": "https://w.test/{query}"}]}"#
        let first = try decode(handWritten).quicklinks
        #expect(first.map(\.name) == ["Wiki"])
        #expect(try decode(handWritten).quicklinks.first?.id == first.first?.id)

        let id = "6F1C2A3B-0000-4000-8000-000000000009"
        let twins = try decode(#"{"quicklinks": [{"id": "\#(id)", "name": "A", "url": "https://a.test"}, {"id": "\#(id)", "name": "B", "url": "https://b.test"}]}"#).quicklinks
        #expect(twins.map(\.name) == ["A", "B"])
        #expect(twins[0].id.uuidString == id)
        #expect(twins[0].id != twins[1].id)

        let copy = try JSONDecoder().decode(SettingsData.self, from: JSONEncoder().encode(try decode(handWritten)))
        #expect(copy.quicklinks == first)
    }

    @Test func `settings are written without escaped slashes`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let url = folder.url.appending(path: "settings.json")
        try SettingsFile(url: url).save(SettingsData())
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("https://www.google.com/search"))
        #expect(!text.contains("\\/"))
    }

    @Test func `non-UUID ids load`() throws {
        let data = try JSONDecoder().decode(SettingsData.self, from: Data(#"{"quicklinks": [{"id": "wiki", "name": "Wiki", "url": "https://w.test"}]}"#.utf8))
        #expect(data.quicklinks.map(\.id) == [Quicklink.derivedID(name: "Wiki", url: "https://w.test")])
    }
}
