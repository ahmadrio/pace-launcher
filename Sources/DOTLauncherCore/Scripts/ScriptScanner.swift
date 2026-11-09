import Foundation

public struct ScriptCommand: Sendable, Equatable, Identifiable {
    /// The script's standardized path.
    public let id: String
    public let url: URL
    public let metadata: ScriptMetadata
    public let isExecutable: Bool
}

/// Finds script commands: any file whose comment header has a title.
public enum ScriptScanner {
    private static let maxFileSize = 512 * 1024

    /// Scans `folders` and their subfolders (down to `maxDepth` levels),
    /// skipping hidden entries. Overlapping folders yield each script once.
    public static func scan(folders: [URL], maxDepth: Int = 3) -> [ScriptCommand] {
        var found: [String: ScriptCommand] = [:]
        for folder in folders {
            walk(folder.standardizedFileURL, depth: 0, maxDepth: maxDepth, into: &found)
        }
        return found.values.sorted {
            $0.metadata.title.localizedStandardCompare($1.metadata.title) == .orderedAscending
        }
    }

    private static func walk(_ folder: URL, depth: Int, maxDepth: Int, into found: inout [String: ScriptCommand]) {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in names where !name.hasPrefix(".") {
            let url = folder.appending(path: name)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                if depth < maxDepth { walk(url, depth: depth + 1, maxDepth: maxDepth, into: &found) }
            } else if let command = command(at: url), found[command.id] == nil {
                found[command.id] = command
            }
        }
    }

    private static func command(at url: URL) -> ScriptCommand? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int), size <= maxFileSize,
              let data = try? Data(contentsOf: url),
              let metadata = ScriptMetadata.parse(String(decoding: data, as: UTF8.self))
        else { return nil }
        return ScriptCommand(
            id: url.path,
            url: url,
            metadata: metadata,
            isExecutable: FileManager.default.isExecutableFile(atPath: url.path)
        )
    }
}
