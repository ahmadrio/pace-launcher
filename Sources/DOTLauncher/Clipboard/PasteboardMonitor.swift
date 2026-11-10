import AppKit
import DOTLauncherCore

/// Polls the general pasteboard and turns each new copy into a ClipDraft.
final class PasteboardMonitor {
    enum Access: Equatable {
        case recording
        /// macOS asks before each programmatic read; reading now would
        /// show an alert on every copy, so recording is paused.
        case needsPermission
        case denied
    }

    /// Larger flavors are skipped; the plain text is still kept.
    private static let maxRepresentationBytes = 5 * 1024 * 1024
    private static let richTypes: [NSPasteboard.PasteboardType] = [.rtf, .html]

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var ownChangeCount: Int?
    private var pollTask: Task<Void, Never>?

    private(set) var access = Access.recording {
        didSet {
            guard access != oldValue else { return }
            Log.clipboard.notice("clipboard access: \(String(describing: self.access), privacy: .public)")
        }
    }

    var onCapture: ((ClipDraft) -> Void)?

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.poll()
            }
        }
    }

    /// Call right after DOT itself writes to the pasteboard so the write
    /// is not recorded as a new copy.
    func ignoreOwnWrite() {
        ownChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }

        // Check before reading: in .ask, every read would raise an alert.
        // lastChangeCount stays put so the copy is picked up once allowed.
        switch pasteboard.accessBehavior {
        case .ask:
            access = .needsPermission
            return
        case .alwaysDeny:
            access = .denied
            return
        default:
            access = .recording
        }

        lastChangeCount = count
        guard count != ownChangeCount else { return }
        capture()
    }

    private func capture() {
        let types = pasteboard.types?.map(\.rawValue) ?? []
        let fileURLs = (pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []
        let text = pasteboard.string(forType: .string)
        let isImage = ClipboardFilter.isImageCopy(types: types, text: text, hasFiles: !fileURLs.isEmpty)

        guard !ClipboardFilter.shouldIgnore(types: types, text: text, hasFiles: !fileURLs.isEmpty, hasImage: isImage) else {
            Log.clipboard.info("skipped a copy (secret, temporary, or unsupported)")
            return
        }

        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if isImage {
            captureImage(from: source)
            return
        }

        let draft: ClipDraft
        if !fileURLs.isEmpty {
            draft = ClipDraft(
                text: fileURLs.map(\.path).joined(separator: "\n"),
                kind: .files, representations: [], sourceBundleID: source, date: .now
            )
        } else {
            var representations: [ClipRepresentation] = []
            for type in Self.richTypes + [.string] {
                guard let data = pasteboard.data(forType: type), data.count <= Self.maxRepresentationBytes else { continue }
                representations.append(ClipRepresentation(type: type.rawValue, data: data))
            }
            let isRich = representations.contains { $0.type != NSPasteboard.PasteboardType.string.rawValue }
            draft = ClipDraft(
                text: text ?? "", kind: isRich ? .richText : .text,
                representations: representations, sourceBundleID: source, date: .now
            )
        }

        Log.clipboard.info("captured \(draft.kind.rawValue, privacy: .public) clip, \(draft.text.count) chars, from \(source ?? "unknown", privacy: .public)")
        onCapture?(draft)
    }

    /// Converts the picture off the main thread (large screenshots take a
    /// moment), then records it.
    private func captureImage(from source: String?) {
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else { return }
        let date = Date.now
        Task {
            guard let image = await Self.convert(data) else {
                Log.clipboard.info("skipped an image (too large or unreadable)")
                return
            }
            Log.clipboard.info("captured image clip \(image.width)×\(image.height), from \(source ?? "unknown", privacy: .public)")
            onCapture?(ClipDraft(
                text: image.description, kind: .image, representations: [],
                sourceBundleID: source, date: date, image: image
            ))
        }
    }

    @concurrent
    private nonisolated static func convert(_ data: Data) async -> ClipImage? {
        ClipImage.make(from: data)
    }
}
