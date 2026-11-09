import Foundation

/// Reusable text, pasted from the launcher.
public struct Snippet: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    /// Optional short trigger such as ";addr", matched in launcher search.
    public var keyword: String?
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), name: String, keyword: String? = nil, content: String,
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
