import Foundation
import Testing
@testable import DOTLauncherCore

struct ScriptScannerTests {
    private func script(_ folder: TemporaryFolder, _ path: String, title: String, executable: Bool = true) throws {
        let url = folder.url.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/bash\n# @raycast.title \(title)\necho hi\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path)
    }

    @Test func `finds scripts in subfolders up to the depth limit`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try script(folder, "top.sh", title: "Top")
        try script(folder, "a/b/two-deep.sh", title: "Two Deep")
        try script(folder, "a/b/c/three-deep.sh", title: "Three Deep")
        try script(folder, "a/b/c/d/too-deep.sh", title: "Too Deep")

        let titles = ScriptScanner.scan(folders: [folder.url], maxDepth: 3).map(\.metadata.title)

        #expect(titles == ["Three Deep", "Top", "Two Deep"])
    }

    @Test func `skips files without a title, hidden entries and images`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try script(folder, "real.sh", title: "Real")
        try script(folder, ".hidden.sh", title: "Hidden")
        try script(folder, ".git/hooks/pre-commit", title: "Hook")
        try folder.write("README.md", "# Scripts\nNo metadata here.")
        try FileManager.default.createDirectory(at: folder.url.appending(path: "images"), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0x00]).write(to: folder.url.appending(path: "images/icon.png"))

        #expect(ScriptScanner.scan(folders: [folder.url]).map(\.metadata.title) == ["Real"])
    }

    @Test func `reports executable bit`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try script(folder, "runs.sh", title: "Runs", executable: true)
        try script(folder, "blocked.sh", title: "Blocked", executable: false)

        let byTitle = Dictionary(uniqueKeysWithValues: ScriptScanner.scan(folders: [folder.url]).map { ($0.metadata.title, $0.isExecutable) })

        #expect(byTitle == ["Runs": true, "Blocked": false])
    }

    @Test func `merges overlapping folders`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try script(folder, "sub/one.sh", title: "One")

        let scripts = ScriptScanner.scan(folders: [folder.url, folder.url.appending(path: "sub")])

        #expect(scripts.map(\.metadata.title) == ["One"])
    }

    @Test func `missing folders are skipped`() {
        #expect(ScriptScanner.scan(folders: [URL(filePath: "/nonexistent-\(UUID().uuidString)")]).isEmpty)
    }
}
