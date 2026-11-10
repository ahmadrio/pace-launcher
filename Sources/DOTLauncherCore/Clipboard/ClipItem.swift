import CryptoKit
import Foundation

public enum ClipKind: String, Sendable {
    case text
    case richText
    case files
    case image
}

/// One pasteboard flavor, such as public.rtf, with its raw bytes.
public struct ClipRepresentation: Sendable, Equatable {
    public let type: String
    public let data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

/// A clipboard copy that has not been stored yet.
public struct ClipDraft: Sendable {
    /// Searchable plain text. For files, the paths, one per line.
    public let text: String
    public let kind: ClipKind
    public let representations: [ClipRepresentation]
    public let sourceBundleID: String?
    public let date: Date
    /// The picture of an image clip, stored as files next to the database.
    public let image: ClipImage?

    public init(text: String, kind: ClipKind, representations: [ClipRepresentation], sourceBundleID: String?, date: Date, image: ClipImage? = nil) {
        self.text = text
        self.kind = kind
        self.representations = representations
        self.sourceBundleID = sourceBundleID
        self.date = date
        self.image = image
    }

    /// Identity for de-duplication: the same visible content copied again
    /// is the same clip, whatever app it came from.
    var contentHash: String {
        var content = Data((kind.rawValue + "\u{0}").utf8)
        // An image is identified by its pixels; its text only names the size.
        content.append(image?.png ?? Data(text.utf8))
        let digest = SHA256.hash(data: content)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// A stored clip, without its (possibly large) representations.
public struct ClipItem: Sendable, Identifiable, Equatable {
    public let id: Int64
    /// Content identity; an image clip's files are named after it.
    public let hash: String
    public let text: String
    public let kind: ClipKind
    public let sourceBundleID: String?
    public let createdAt: Date
    public let lastUsedAt: Date
    public let useCount: Int
    public let pinned: Bool
}
