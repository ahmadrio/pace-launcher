import AppKit
import SwiftUI
import DOTLauncherCore

/// Connects the pasteboard monitor, the clip store, and the launcher's
/// clipboard mode.
final class ClipboardController {
    let monitor = PasteboardMonitor()
    private let store: ClipboardStore
    private let icons: IconCache
    private var appNames: [String: String] = [:]
    /// Bounded: scrolling a long history must not keep every thumbnail.
    private var thumbnails = RecentCache<String, NSImage>(capacity: 300)
    /// The clips behind the rows currently listed, by row id.
    private var listed: [String: ClipItem] = [:]
    /// `ClipStats.summary` by clip hash: counting a long clip is O(n).
    private var textSummaries = RecentCache<String, String>(capacity: 300)
    private let previewImages = PreviewImageLoader()
    /// Shows a one-line message in the panel footer.
    var onNotice: ((String) -> Void)?
    /// Called after a pin or delete finishes, to refresh the list.
    var onChange: (() -> Void)?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(store: ClipboardStore, icons: IconCache) {
        self.store = store
        self.icons = icons
        monitor.onCapture = { [store] draft in
            Task {
                do {
                    try await store.save(draft)
                } catch {
                    Log.clipboard.error("could not save clip: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    func start() {
        monitor.start()
    }

    func results(for query: String) async -> [LauncherResult] {
        do {
            let items = try await store.search(query, limit: 100)
            listed = Dictionary(items.map { ("clip:\($0.id)", $0) }, uniquingKeysWith: { first, _ in first })
            return items.map(result(for:))
        } catch {
            Log.clipboard.error("clipboard search failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    func preview(for result: LauncherResult) -> AnyView? {
        guard let item = listed[result.id] else { return nil }
        let summary = textSummaries.value(for: item.hash) ?? ClipStats.summary(for: item.text)
        textSummaries.insert(summary, for: item.hash)
        return AnyView(ClipPreviewView(
            item: item,
            imageURL: store.imageURL(for: item),
            appName: item.sourceBundleID.flatMap(appName(for:)),
            textSummary: summary,
            images: previewImages
        ))
    }

    private func result(for item: ClipItem) -> LauncherResult {
        let firstLine = item.text
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? item.text
        let lineCount = item.text.split(whereSeparator: \.isNewline).count
        let app = item.sourceBundleID.flatMap(appName(for:))
        let when = Self.relativeFormatter.localizedString(for: item.lastUsedAt, relativeTo: .now)
        var details = [app, when].compactMap { $0 }
        if lineCount > 1 { details.append("\(lineCount) lines") }
        let kind = switch item.kind {
        case .text: "Text"
        case .richText: "Rich Text"
        case .files: "Files"
        case .image: "Image"
        }

        // An image whose file is gone (restored from a backup) cannot be
        // pasted: say so and keep the panel open.
        let missingImage = item.kind == .image && store.imageURL(for: item) == nil
        return LauncherResult(
            id: "clip:\(item.id)",
            title: String(firstLine.prefix(200)),
            subtitle: missingImage ? "Image unavailable" : details.joined(separator: " · "),
            icon: icon(for: item),
            accessory: item.pinned ? "Pinned" : kind,
            actionTitle: "Paste",
            action: missingImage
                ? .stay { [weak self] in self?.onNotice?("Image unavailable") }
                : .run { [weak self] in self?.paste(item) },
            secondaryActions: plainTextAction(for: item, missingImage: missingImage) + [
                SecondaryAction(title: item.pinned ? "Unpin" : "Pin", shortcut: .command("p"), action: .stay { [weak self] in
                    // Toggled in the database: the row's `pinned` may be stale.
                    self?.change { try await $0.togglePinned(item.id) }
                }),
                SecondaryAction(title: "Delete", shortcut: .delete, confirm: true, action: .stay { [weak self] in
                    self?.change { try await $0.delete(item.id) }
                }),
            ]
        )
    }

    /// Runs a store change, then refreshes the list (the store is an actor,
    /// so the refresh must wait for the change).
    private func change(_ work: @escaping (ClipboardStore) async throws -> Void) {
        Task {
            do {
                try await work(store)
            } catch {
                Log.clipboard.error("clip change failed: \(String(describing: error), privacy: .public)")
            }
            onChange?()
        }
    }

    /// ⌘⇧↩ for clips that have text (not images).
    private func plainTextAction(for item: ClipItem, missingImage: Bool) -> [SecondaryAction] {
        guard !missingImage, let text = item.plainText else { return [] }
        return [SecondaryAction(
            title: "Paste as Plain Text",
            shortcut: KeyShortcut(key: "\r", modifiers: [.command, .shift]),
            action: .run { [weak self] in self?.pastePlainText(text, of: item) }
        )]
    }

    private func pastePlainText(_ text: String, of item: ClipItem) {
        Paster.pastePlainText(text, monitor: monitor)
        Task {
            do {
                try await store.markUsed(item.id)
            } catch {
                Log.clipboard.error("could not mark a clip as used: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func paste(_ item: ClipItem) {
        Task {
            do {
                let representations = try await store.representations(of: item.id)
                Paster.paste(item, representations: representations, imageURL: store.imageURL(for: item), monitor: monitor)
                try await store.markUsed(item.id)
            } catch {
                Log.clipboard.error("paste failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func icon(for item: ClipItem) -> LauncherResult.Icon {
        if item.kind == .image {
            if let cached = thumbnails.value(for: item.hash) { return .image(cached) }
            guard let url = store.thumbnailURL(for: item), let thumbnail = NSImage(contentsOf: url) else { return .symbol("photo") }
            thumbnails.insert(thumbnail, for: item.hash)
            return .image(thumbnail)
        }
        if item.kind == .files, let first = item.text.split(separator: "\n").first {
            return .image(icons.icon(forPath: String(first)))
        }
        if let bundleID = item.sourceBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return .image(icons.icon(forPath: url.path))
        }
        return .symbol("doc.text")
    }

    private func appName(for bundleID: String) -> String? {
        if let cached = appNames[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        appNames[bundleID] = name
        return name
    }
}
