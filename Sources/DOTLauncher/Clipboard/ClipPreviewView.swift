import AppKit
import DOTLauncherCore
import Observation
import SwiftUI

/// The selected clip in full, next to the clipboard list.
struct ClipPreviewView: View {
    let item: ClipItem
    let imageURL: URL?
    let appName: String?
    let images: PreviewImageLoader

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(0.5)
            Text(details)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text, .richText:
            ScrollView {
                Text(item.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        case .image:
            ClipImagePreview(url: imageURL, images: images)
        case .files:
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.text.split(separator: "\n").map(String.init), id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(path)
                                .font(.system(size: 12))
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }

    private var details: String {
        var parts: [String] = []
        if let appName { parts.append(appName) }
        parts.append("Copied " + Self.relative.localizedString(for: item.lastUsedAt, relativeTo: .now))
        parts.append(item.useCount == 1 ? "Used once" : "Used \(item.useCount) times")
        switch item.kind {
        case .text, .richText:
            parts.append(ClipStats.summary(for: item.text))
        case .image:
            parts.append(item.text.replacingOccurrences(of: "Image ", with: ""))
        case .files:
            let count = item.text.split(separator: "\n").count
            parts.append(count == 1 ? "1 file" : "\(count) files")
        }
        return parts.joined(separator: " · ")
    }
}

private struct ClipImagePreview: View {
    let url: URL?
    let images: PreviewImageLoader

    var body: some View {
        Group {
            if let url, images.url == url {
                if let image = images.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    unavailable
                }
            } else if url == nil {
                unavailable
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) { await images.load(url) }
    }

    private var unavailable: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Image unavailable")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Reads the selected image's file off the main thread, one at a time.
@Observable
final class PreviewImageLoader {
    private(set) var url: URL?
    private(set) var image: NSImage?

    func load(_ url: URL?) async {
        guard let url, url != self.url else { return }
        let data = await Self.read(url)
        guard !Task.isCancelled else { return }
        self.url = url
        image = data.flatMap(NSImage.init(data:))
    }

    @concurrent
    private nonisolated static func read(_ url: URL) async -> Data? {
        try? Data(contentsOf: url)
    }
}
