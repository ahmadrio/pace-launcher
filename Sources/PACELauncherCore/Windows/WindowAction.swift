public enum WindowAction: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, almostMaximize, center
    case restore

    public var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left Quarter"
        case .topRight: "Top Right Quarter"
        case .bottomLeft: "Bottom Left Quarter"
        case .bottomRight: "Bottom Right Quarter"
        case .maximize: "Maximize"
        case .almostMaximize: "Almost Maximize"
        case .center: "Center"
        case .restore: "Restore"
        }
    }

    /// Same defaults as Rectangle, so muscle memory carries over.
    public var defaultHotKey: String? {
        switch self {
        case .leftHalf: "ctrl+opt+left"
        case .rightHalf: "ctrl+opt+right"
        case .topHalf: "ctrl+opt+up"
        case .bottomHalf: "ctrl+opt+down"
        case .topLeft: "ctrl+opt+u"
        case .topRight: "ctrl+opt+i"
        case .bottomLeft: "ctrl+opt+j"
        case .bottomRight: "ctrl+opt+k"
        case .maximize: "ctrl+opt+return"
        case .center: "ctrl+opt+c"
        case .restore: "ctrl+opt+delete"
        case .almostMaximize: nil
        }
    }
}
