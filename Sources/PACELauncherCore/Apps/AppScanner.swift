import Foundation

/// Finds .app bundles by walking folders. Does not depend on Spotlight, so
/// it works with indexing off and inside tests.
public struct AppScanner: Sendable {
    public struct Root: Sendable {
        public let url: URL
        /// 1 = only the folder itself, 2 = one subfolder down, …
        public let maxDepth: Int

        public init(url: URL, maxDepth: Int) {
            self.url = url
            self.maxDepth = maxDepth
        }
    }

    public let roots: [Root]
    /// Individual apps outside the scanned folders (Finder, for example).
    public let extraApps: [URL]

    public init(roots: [Root], extraApps: [URL] = []) {
        self.roots = roots
        self.extraApps = extraApps
    }

    /// The standard macOS application folders.
    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> AppScanner {
        AppScanner(
            roots: [
                Root(url: URL(filePath: "/Applications"), maxDepth: 2),
                Root(url: URL(filePath: "/System/Applications"), maxDepth: 2),
                Root(url: home.appending(path: "Applications"), maxDepth: 2),
            ],
            extraApps: [URL(filePath: "/System/Library/CoreServices/Finder.app")]
        )
    }

    public func scan() -> [AppEntry] {
        var found: [AppEntry] = []
        for root in roots {
            walk(root.url, depthLeft: root.maxDepth, into: &found)
        }
        found += extraApps.compactMap(entry(for:))
        return found
    }

    /// Scans off the calling actor.
    @concurrent
    public func scanInBackground() async -> [AppEntry] {
        AppCatalog.deduplicated(scan())
    }

    private func walk(_ folder: URL, depthLeft: Int, into found: inout [AppEntry]) {
        // List names and build child URLs from `folder` ourselves, so paths
        // keep the caller's spelling (FileManager's URL variant would turn
        // /var into /private/var, for example).
        guard depthLeft > 0, let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else {
            return
        }

        for name in names where !name.hasPrefix(".") {
            let child = folder.appending(path: name)
            if child.pathExtension == "app" {
                if let entry = entry(for: child) { found.append(entry) }
                continue
            }
            let resolved = child.resolvingSymlinksInPath()
            let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                walk(child, depthLeft: depthLeft - 1, into: &found)
            }
        }
    }

    private func entry(for appURL: URL) -> AppEntry? {
        let resolved = appURL.resolvingSymlinksInPath()
        let plistURL = resolved.appending(path: "Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }

        let info = (try? Data(contentsOf: plistURL))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
            ?? [:]

        let name = appURL.deletingPathExtension().lastPathComponent
        let aliases = [info["CFBundleDisplayName"], info["CFBundleName"]]
            .compactMap { $0 as? String }
            .filter { !$0.isEmpty && $0 != name }

        return AppEntry(
            name: name,
            bundleID: info["CFBundleIdentifier"] as? String,
            path: appURL.path,
            aliases: Array(NSOrderedSet(array: aliases)) as? [String] ?? aliases
        )
    }
}
