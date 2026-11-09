import CryptoKit
import Foundation

public enum ClipKind: String, Sendable {
    case text
    case richText
    case files
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

    public init(text: String, kind: ClipKind, representations: [ClipRepresentation], sourceBundleID: String?, date: Date) {
        self.text = text
        self.kind = kind
        self.representations = representations
        self.sourceBundleID = sourceBundleID
        self.date = date
    }

    /// Identity for de-duplication: the same visible content copied again
    /// is the same clip, whatever app it came from.
    var contentHash: String {
        let digest = SHA256.hash(data: Data((kind.rawValue + "\u{0}" + text).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// A stored clip, without its (possibly large) representations.
public struct ClipItem: Sendable, Identifiable, Equatable {
    public let id: Int64
    public let text: String
    public let kind: ClipKind
    public let sourceBundleID: String?
    public let createdAt: Date
    public let lastUsedAt: Date
    public let useCount: Int
    public let pinned: Bool
}
