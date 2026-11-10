import AppKit
import PACELauncherCore
import Observation

/// The script commands found in the main Scripts folder plus any extra
/// folders the user added (those are per-Mac and never synced).
@Observable
final class ScriptLibrary {
    static let extraFoldersKey = "extraScriptFolders"

    private(set) var scripts: [ScriptCommand] = []
    @ObservationIgnored var onChange: (() -> Void)?
    /// Bumped when the extra folders change, so Settings re-reads them.
    private(set) var foldersVersion = 0

    var folders: [URL] {
        [AppPaths.scriptsDirectory] + extraFolders
    }

    var extraFolders: [URL] {
        (UserDefaults.standard.stringArray(forKey: Self.extraFoldersKey) ?? []).map { URL(filePath: $0) }
    }

    func setExtraFolders(_ urls: [URL]) {
        UserDefaults.standard.set(urls.map(\.path), forKey: Self.extraFoldersKey)
        foldersVersion += 1
        reload()
    }

    func reload() {
        scripts = ScriptScanner.scan(folders: folders)
        onChange?()
    }

    /// Writes a starter script into the main folder and opens it.
    func createTemplate() {
        let folder = AppPaths.scriptsDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var url = folder.appending(path: "my-script.sh")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "my-script-\(index).sh")
            index += 1
        }
        let template = """
        #!/bin/bash

        # PACE Launcher script command. Metadata lines also accept @raycast.
        # @pace.title My Script
        # @pace.mode fullOutput
        # @pace.packageName Custom
        # @pace.icon 🛠️
        # @pace.argument1 { "type": "text", "placeholder": "Name", "optional": true }

        echo "Hello${1:+, $1} from PACE Launcher"

        """
        do {
            try Data(template.utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            openForEditing(url)
        } catch {
            Log.app.error("could not create script: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    /// Opens a script in the default plain-text editor. The default app for
    /// `.sh` is often a terminal, which would run the script instead.
    private func openForEditing(_ url: URL) {
        guard let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            Task { @MainActor in
                Log.app.error("could not open \(url.lastPathComponent, privacy: .public) in an editor: \(error.localizedDescription, privacy: .public)")
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    func openFolder() {
        let folder = AppPaths.scriptsDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    /// The icon from `@….icon`: an emoji, or an image path relative to the
    /// script (URLs are not fetched).
    static func icon(for script: ScriptCommand) -> LauncherResult.Icon {
        guard let value = script.metadata.icon, !value.isEmpty else { return .symbol("terminal") }
        if value.hasPrefix("http") { return .symbol("terminal") }
        if value.count <= 2, value.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x238C }) {
            return .text(value)
        }
        let expanded = (value as NSString).expandingTildeInPath
        let url = expanded.hasPrefix("/") ? URL(filePath: expanded) : script.url.deletingLastPathComponent().appending(path: expanded)
        if let image = NSImage(contentsOf: url) { return .image(image) }
        return value.count <= 2 ? .text(value) : .symbol("terminal")
    }
}
