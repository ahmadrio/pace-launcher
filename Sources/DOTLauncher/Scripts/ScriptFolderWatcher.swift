import CoreServices
import Foundation

/// Tells the app when files change in the script folders (FSEvents, half a
/// second of coalescing), so new or restored scripts and their shortcuts
/// appear without opening the launcher.
final class ScriptFolderWatcher {
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private var watched: [String] = []

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    /// Watches the folders that exist; does nothing when that set is unchanged.
    func watch(_ folders: [URL]) {
        let paths = folders.map(\.path).filter { FileManager.default.fileExists(atPath: $0) }.sorted()
        guard paths != watched else { return }
        stop()
        watched = paths
        guard !paths.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            nil, scriptFolderEventCallback, &context, paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
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

    fileprivate func changed() {
        onChange()
    }
}

/// FSEvents delivers on the main queue (set above).
private nonisolated func scriptFolderEventCallback(
    _ stream: ConstFSEventStreamRef, _ info: UnsafeMutableRawPointer?, _ count: Int,
    _ paths: UnsafeMutableRawPointer, _ flags: UnsafePointer<FSEventStreamEventFlags>, _ ids: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    // Raw pointers are not Sendable; pass the address. The watcher lives
    // as long as the app (AppDelegate keeps it).
    let address = UInt(bitPattern: info)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<ScriptFolderWatcher>.fromOpaque(pointer).takeUnretainedValue().changed()
    }
}
