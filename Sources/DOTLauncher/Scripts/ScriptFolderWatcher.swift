import CoreServices
import DOTLauncherCore
import Foundation

/// Tells the app when files change in the script folders (FSEvents, half a
/// second of coalescing), so new or restored scripts and their shortcuts
/// appear without opening the launcher.
final class ScriptFolderWatcher {
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private var watched: [String] = []
    /// The script folders themselves, for telling which changes matter.
    private var folders: [String] = []

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    /// Watches the folders (also ones that do not exist yet); does nothing
    /// when they are unchanged.
    func watch(_ folders: [URL]) {
        // FSEvents reports real paths (/private/tmp, symlink targets).
        self.folders = folders.map { ScriptFolderEvents.resolved($0.path) }
        let paths = ScriptFolderEvents.watchPaths(for: self.folders)
        guard paths != watched else { return }
        stop()
        watched = paths
        guard !paths.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            nil, scriptFolderEventCallback, &context, paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            Log.app.error("could not watch the script folders")
            return
        }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Reloads only for changes the scanner can see: not .git, not deeper
    /// than it looks, not Notes next to a missing Scripts folder.
    fileprivate func changed(paths: [String]) {
        guard paths.contains(where: { ScriptFolderEvents.isRelevant($0, folders: folders) }) else { return }
        Log.app.debug("script folders changed")
        onChange()
    }
}

/// FSEvents delivers on the main queue (set above).
private nonisolated func scriptFolderEventCallback(
    _ stream: ConstFSEventStreamRef, _ info: UnsafeMutableRawPointer?, _ count: Int,
    _ paths: UnsafeMutableRawPointer, _ flags: UnsafePointer<FSEventStreamEventFlags>, _ ids: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    // With kFSEventStreamCreateFlagUseCFTypes, `paths` is a CFArray of CFString.
    let changedPaths = (unsafeBitCast(paths, to: NSArray.self) as? [String]) ?? []
    // Raw pointers are not Sendable; pass the address. The watcher lives
    // as long as the app (AppDelegate keeps it).
    let address = UInt(bitPattern: info)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<ScriptFolderWatcher>.fromOpaque(pointer).takeUnretainedValue().changed(paths: changedPaths)
    }
}
