/// Built-in launcher commands that can get a global shortcut. Raw values
/// are the launcher command ids.
public enum CommandShortcut: String, CaseIterable, Sendable {
    case translate
    case aiChat = "ai-chat"
    case aiChatHistory = "ai-chat-history"
    case openNotes = "open-notes"
    case createNote = "create-note"
    case searchNotes = "search-notes"
    case searchSnippets = "search-snippets"
    case createSnippet = "create-snippet"
    case settings

    public var title: String {
        switch self {
        case .translate: "Translate"
        case .aiChat: "AI Chat"
        case .aiChatHistory: "AI Chat History"
        case .openNotes: "Open Notes"
        case .createNote: "Create Note"
        case .searchNotes: "Search Notes"
        case .searchSnippets: "Search Snippets"
        case .createSnippet: "Create Snippet"
        case .settings: "Settings"
        }
    }
}
