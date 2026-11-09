import Foundation

enum AppPaths {
    /// ~/Library/Application Support/DOT Launcher, created on first use.
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "DOT Launcher")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static var launcherDatabase: URL { supportDirectory.appending(path: "launcher.sqlite") }
    static var clipboardDatabase: URL { supportDirectory.appending(path: "clipboard.sqlite") }
    /// One JSON file per snippet; sync-friendly (tahap 3).
    static var snippetsDirectory: URL { supportDirectory.appending(path: "Snippets") }
    /// One Markdown file per note.
    static var notesDirectory: URL { supportDirectory.appending(path: "Notes") }
}
