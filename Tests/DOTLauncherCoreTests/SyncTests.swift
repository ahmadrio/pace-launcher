import Foundation
import Testing
@testable import DOTLauncherCore

struct ICloudPlaceholderTests {
    @Test func `recognises iCloud placeholder names`() {
        #expect(ICloudPlaceholder.originalName(of: ".A.md.icloud") == "A.md")
        #expect(ICloudPlaceholder.originalName(of: "A.md") == nil)
        #expect(ICloudPlaceholder.originalName(of: ".DS_Store") == nil)
        #expect(ICloudPlaceholder.originalName(of: ".icloud") == nil)
    }
}

struct FolderMigrationTests {
    private func write(_ folder: URL, _ path: String, _ text: String) throws {
        let url = folder.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func read(_ folder: URL, _ path: String) -> String? {
        (try? Data(contentsOf: folder.appending(path: path))).map { String(decoding: $0, as: UTF8.self) }
    }

    @Test func `moves files and folders without losing any`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "local"), destination = root.url.appending(path: "icloud")
        try write(source, "Notes/a.md", "A")
        try write(source, "Snippets/s.json", "S")
        try write(source, "settings.json", "{}")

        let report = try FolderMigration.move(from: source, to: destination, label: "This Mac")

        #expect(read(destination, "Notes/a.md") == "A")
        #expect(read(destination, "Snippets/s.json") == "S")
        #expect(read(destination, "settings.json") == "{}")
        #expect(report.moved.sorted() == ["Notes/a.md", "Snippets/s.json", "settings.json"])
        #expect(read(source, "Notes/a.md") == nil)
    }

    @Test func `keeps both files on a name clash`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "local"), destination = root.url.appending(path: "icloud")
        try write(source, "Notes/a.md", "local version")
        try write(destination, "Notes/a.md", "cloud version")

        let report = try FolderMigration.move(from: source, to: destination, label: "This Mac")

        #expect(read(destination, "Notes/a.md") == "cloud version")
        #expect(read(destination, "Notes/a (from This Mac).md") == "local version")
        #expect(report.renamed == ["Notes/a.md": "Notes/a (from This Mac).md"])
    }

    @Test func `resumes a half-finished migration without losing files`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "local"), destination = root.url.appending(path: "icloud")
        for index in 0..<6 { try write(source, "Notes/\(index).md", "note \(index)") }
        // A previous run copied half of the files, then stopped before deleting.
        for index in 0..<3 { try write(destination, "Notes/\(index).md", "note \(index)") }

        _ = try FolderMigration.move(from: source, to: destination, label: "This Mac")

        for index in 0..<6 {
            #expect(read(destination, "Notes/\(index).md") == "note \(index)")
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: destination.appending(path: "Notes").path).sorted()
        #expect(names == (0..<6).map { "\($0).md" })   // identical copies are not duplicated
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: source.appending(path: "Notes").path)) ?? []).isEmpty)
    }

    @Test func `moves a single file to the destination path`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        try write(root.url, "local/settings.json", "{\"a\":1}")

        let report = try FolderMigration.move(
            from: root.url.appending(path: "local/settings.json"),
            to: root.url.appending(path: "icloud/settings.json"),
            label: "This Mac"
        )

        #expect(read(root.url, "icloud/settings.json") == "{\"a\":1}")
        #expect(read(root.url, "local/settings.json") == nil)
        #expect(report.moved == ["settings.json"])
    }

    @Test func `leaves iCloud placeholders in the source and reports them`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "icloud"), destination = root.url.appending(path: "local")
        try write(source, "Notes/.b.md.icloud", "stub")
        try write(source, "Notes/a.md", "A")

        let report = try FolderMigration.move(from: source, to: destination, label: "iCloud")

        #expect(report.skipped == ["Notes/.b.md.icloud"])
        #expect(read(source, "Notes/.b.md.icloud") == "stub")
        #expect(read(destination, "Notes/.b.md.icloud") == nil)
        #expect(read(destination, "Notes/a.md") == "A")
    }

    @Test func `never writes onto a file iCloud has not downloaded yet`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "local"), destination = root.url.appending(path: "icloud")
        try write(source, "Notes/a.md", "local")
        try write(destination, "Notes/.a.md.icloud", "stub")

        let report = try FolderMigration.move(from: source, to: destination, label: "This Mac")

        #expect(read(destination, "Notes/a.md") == nil)
        #expect(read(destination, "Notes/.a.md.icloud") == "stub")
        #expect(read(destination, "Notes/a (from This Mac).md") == "local")
        #expect(report.renamed == ["Notes/a.md": "Notes/a (from This Mac).md"])
    }

    @Test func `a single file never lands on an evicted one`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        try write(root.url, "local/settings.json", "{}")
        try write(root.url, "icloud/.settings.json.icloud", "stub")

        let report = try FolderMigration.move(
            from: root.url.appending(path: "local/settings.json"),
            to: root.url.appending(path: "icloud/settings.json"),
            label: "This Mac"
        )

        #expect(read(root.url, "icloud/settings.json") == nil)
        #expect(read(root.url, "icloud/settings (from This Mac).json") == "{}")
        #expect(report.renamed == ["settings.json": "settings (from This Mac).json"])
    }

    @Test func `a failed move reports what it already moved`() throws {
        let root = TemporaryFolder()
        defer { root.remove() }
        let source = root.url.appending(path: "local"), destination = root.url.appending(path: "icloud")
        try write(source, "Notes/a.md", "A")
        try write(source, "Snippets/s.json", "S")
        // A file where the Snippets folder should go makes the second half fail.
        try write(destination, "Snippets", "in the way")

        #expect {
            _ = try FolderMigration.move(from: source, to: destination, label: "This Mac")
        } throws: { error in
            (error as? FolderMigration.Interrupted)?.report.moved == ["Notes/a.md"]
        }
        #expect(read(destination, "Notes/a.md") == "A")
        #expect(read(source, "Snippets/s.json") == "S")
    }
}

struct BackupRotationTests {
    @Test func `backup names sort and prune to five`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for hour in 0..<7 {
            let name = BackupRotation.fileName(for: base.addingTimeInterval(Double(hour) * 3600))
            try Data().write(to: folder.url.appending(path: name))
        }
        try folder.write("notes.txt", "not a backup")

        let backups = BackupRotation.backups(in: folder.url)
        #expect(backups.count == 7)
        #expect(backups.first?.date == base.addingTimeInterval(6 * 3600))

        try BackupRotation.prune(in: folder.url, keep: 5)

        let kept = BackupRotation.backups(in: folder.url)
        #expect(kept.count == 5)
        #expect(kept.last?.date == base.addingTimeInterval(2 * 3600))
        #expect(FileManager.default.fileExists(atPath: folder.url.appending(path: "notes.txt").path))
    }

    @Test func `lists backups that iCloud has not downloaded yet`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let name = BackupRotation.fileName(for: date)
        try folder.write(".\(name).icloud", "stub")

        let backups = BackupRotation.backups(in: folder.url)

        #expect(backups.map(\.date) == [date])
        #expect(backups.first?.url.lastPathComponent == ".\(name).icloud")
    }
}

struct ClipboardBackupTests {
    private func draft(_ text: String) -> ClipDraft {
        ClipDraft(text: text, kind: .text, representations: [], sourceBundleID: nil, date: .now)
    }

    @Test func `clipboard backup and restore round-trip`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let store = try ClipboardStore(path: folder.url.appending(path: "clipboard.sqlite").path)
        let backup = folder.url.appending(path: "backup.sqlite").path

        for text in ["one", "two", "three"] { try await store.save(draft(text)) }
        try await store.backup(to: backup)
        for text in ["four", "five"] { try await store.save(draft(text)) }
        #expect(try await store.count() == 5)

        try await store.restore(from: backup)

        #expect(try await store.count() == 3)
        #expect(try await store.search("two").map(\.text) == ["two"])
    }

    @Test func `a backup is one file with no -wal or -shm beside it`() async throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let store = try ClipboardStore(path: folder.url.appending(path: "clipboard.sqlite").path)
        try await store.save(draft("one"))
        let backups = folder.url.appending(path: "out")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)

        try await store.backup(to: backups.appending(path: "backup.sqlite").path)

        #expect(try FileManager.default.contentsOfDirectory(atPath: backups.path) == ["backup.sqlite"])
    }
}

struct RenamedCopyTests {
    @Test func `notes renamed during a move get their own id and stay listed`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let id = UUID()
        try folder.write("\(id.uuidString).md", "# Cloud")
        try folder.write("\(id.uuidString) (from This Mac).md", "# Local")
        let notes = NoteStore(directory: folder.url) { _ in }

        #expect(try notes.adoptRenamedCopies() == 1)

        let titles = try notes.list().map(\.title).sorted()
        #expect(titles == ["Cloud", "Local"])
        #expect(folder.files().allSatisfy { UUID(uuidString: String($0.dropLast(3))) != nil })
    }

    @Test func `snippets renamed during a move get their own id and stay listed`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let store = SnippetStore(directory: folder.url)
        let original = Snippet(name: "Address", keyword: ";addr", content: "Jl. Contoh 1")
        try store.save(original)
        let file = folder.url.appending(path: "\(original.id.uuidString).json")
        try FileManager.default.copyItem(at: file, to: folder.url.appending(path: "\(original.id.uuidString) (from This Mac).json"))

        #expect(try store.adoptRenamedCopies() == 1)

        let all = try store.all()
        #expect(all.count == 2)
        #expect(Set(all.map(\.id)).count == 2)
        #expect(all.allSatisfy { $0.name == "Address" && $0.keyword == ";addr" })
    }

    @Test func `other files are left alone`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        try folder.write("notes.txt", "x")
        try folder.write("Untitled (from This Mac).md", "x")
        #expect(try NoteStore(directory: folder.url) { _ in }.adoptRenamedCopies() == 0)
        #expect(folder.files() == ["Untitled (from This Mac).md", "notes.txt"])
    }
}

struct StorePlaceholderTests {
    @Test func `stores report placeholders instead of dropping them`() throws {
        let folder = TemporaryFolder()
        defer { folder.remove() }
        let id = UUID()
        try folder.write(".\(id.uuidString).md.icloud", "placeholder plist")
        let notes = NoteStore(directory: folder.url) { _ in }

        #expect(try notes.list().isEmpty)
        #expect(notes.placeholders().map(\.lastPathComponent) == [".\(id.uuidString).md.icloud"])

        let snippetID = UUID()
        try folder.write(".\(snippetID.uuidString).json.icloud", "placeholder plist")
        #expect(SnippetStore(directory: folder.url).placeholders().map(\.lastPathComponent) == [".\(snippetID.uuidString).json.icloud"])
    }
}
