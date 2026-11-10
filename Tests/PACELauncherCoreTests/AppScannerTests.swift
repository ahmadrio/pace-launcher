import Foundation
import Testing
@testable import PACELauncherCore

/// Builds fake .app bundles in a temporary folder.
private struct FakeApps {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "PACELauncherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult
    func makeApp(_ relativePath: String, bundleID: String?, displayName: String? = nil) throws -> URL {
        let app = root.appending(path: relativePath)
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var plist: [String: Any] = ["CFBundlePackageType": "APPL"]
        plist["CFBundleIdentifier"] = bundleID
        plist["CFBundleDisplayName"] = displayName
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist"))
        return app
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

struct AppScannerTests {
    @Test func `finds apps at the top level and one folder down`() throws {
        let fake = try FakeApps()
        defer { fake.remove() }
        try fake.makeApp("Applications/Safari.app", bundleID: "com.apple.Safari")
        try fake.makeApp("Applications/Utilities/Terminal.app", bundleID: "com.apple.Terminal")
        try fake.makeApp("Applications/Deep/Deeper/Hidden.app", bundleID: "com.example.hidden")

        let scanner = AppScanner(roots: [.init(url: fake.root.appending(path: "Applications"), maxDepth: 2)])
        let names = scanner.scan().map(\.name).sorted()

        #expect(names == ["Safari", "Terminal"])
    }

    @Test func `does not look inside app bundles`() throws {
        let fake = try FakeApps()
        defer { fake.remove() }
        try fake.makeApp("Applications/Xcode.app", bundleID: "com.apple.dt.Xcode")
        try fake.makeApp("Applications/Xcode.app/Contents/Applications/Simulator.app", bundleID: "com.apple.iphonesimulator")

        let scanner = AppScanner(roots: [.init(url: fake.root.appending(path: "Applications"), maxDepth: 3)])

        #expect(scanner.scan().map(\.name) == ["Xcode"])
    }

    @Test func `follows symlinked apps`() throws {
        let fake = try FakeApps()
        defer { fake.remove() }
        let real = try fake.makeApp("Cryptex/Safari.app", bundleID: "com.apple.Safari")
        let applications = fake.root.appending(path: "Applications")
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: applications.appending(path: "Safari.app"), withDestinationURL: real)

        let scanner = AppScanner(roots: [.init(url: applications, maxDepth: 1)])
        let entry = try #require(scanner.scan().first)

        #expect(entry.name == "Safari")
        #expect(entry.bundleID == "com.apple.Safari")
        #expect(entry.path == applications.appending(path: "Safari.app").path)
        #expect(!entry.path.contains("Cryptex"))
    }

    @Test func `reads bundle id and display name as an alias`() throws {
        let fake = try FakeApps()
        defer { fake.remove() }
        try fake.makeApp("Applications/Visual Studio Code.app", bundleID: "com.microsoft.VSCode", displayName: "Code")

        let scanner = AppScanner(roots: [.init(url: fake.root.appending(path: "Applications"), maxDepth: 1)])
        let entry = try #require(scanner.scan().first)

        #expect(entry.name == "Visual Studio Code")
        #expect(entry.bundleID == "com.microsoft.VSCode")
        #expect(entry.aliases == ["Code"])
    }

    @Test func `skips missing roots`() {
        let scanner = AppScanner(roots: [.init(url: URL(filePath: "/nonexistent-\(UUID().uuidString)"), maxDepth: 1)])
        #expect(scanner.scan().isEmpty)
    }
}

struct AppCatalogTests {
    @Test func `deduplicates by bundle id preferring the main Applications folder`() {
        let entries = [
            AppEntry(name: "Safari", bundleID: "com.apple.Safari", path: "/Users/me/Applications/Safari.app"),
            AppEntry(name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app"),
            AppEntry(name: "Mail", bundleID: "com.apple.mail", path: "/System/Applications/Mail.app"),
        ]

        let result = AppCatalog.deduplicated(entries)

        #expect(result.map(\.path) == ["/System/Applications/Mail.app", "/Applications/Safari.app"])
    }

    @Test func `keeps apps without a bundle id, deduplicated by path`() {
        let entries = [
            AppEntry(name: "Tool", bundleID: nil, path: "/Applications/Tool.app"),
            AppEntry(name: "Tool", bundleID: nil, path: "/Applications/Tool.app"),
            AppEntry(name: "Other", bundleID: nil, path: "/Applications/Other.app"),
        ]

        #expect(AppCatalog.deduplicated(entries).map(\.name) == ["Other", "Tool"])
    }
}
