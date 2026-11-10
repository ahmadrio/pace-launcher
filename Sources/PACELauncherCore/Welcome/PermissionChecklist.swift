/// The macOS permissions PACE uses, what each is for, and how the welcome
/// window describes their state.
public enum PermissionKind: CaseIterable, Sendable, Hashable {
    case accessibility, inputMonitoring, clipboard, automation

    public var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .clipboard: "Paste from Other Apps"
        case .automation: "Automation"
        }
    }

    public var purpose: String {
        switch self {
        case .accessibility: "Window snapping, pasting into other apps, Lock Screen and Log Out."
        case .inputMonitoring: "Snippet keywords that expand as you type."
        case .clipboard: "Clipboard history."
        case .automation: "Restart, Shut Down, Empty Trash and Toggle Dark Mode."
        }
    }

    /// SF Symbol for the row.
    public var symbol: String {
        switch self {
        case .accessibility: "hand.raised"
        case .inputMonitoring: "keyboard"
        case .clipboard: "doc.on.clipboard"
        case .automation: "gearshape.2"
        }
    }
}

public enum PermissionState: Equatable, Sendable, Hashable {
    case granted, missing
    /// Input Monitoring while auto-expand is switched off.
    case notNeeded
    /// Input Monitoring is granted but auto-expand could not start yet.
    case needsRelaunch
    case asksEachTime, denied, unavailable
    /// Automation: macOS shows its own prompt per app on first use.
    case asksOnFirstUse

    public var label: String {
        switch self {
        case .granted: "Granted"
        case .missing: "Not granted"
        case .notNeeded: "Not needed while auto-expand is off"
        case .needsRelaunch: "Granted — quit and reopen PACE to start"
        case .asksEachTime: "Asks each time"
        case .denied: "Denied"
        case .unavailable: "Unavailable"
        case .asksOnFirstUse: "macOS asks the first time you use one"
        }
    }

    /// The row offers a button to System Settings.
    public var needsAction: Bool {
        switch self {
        case .missing, .asksEachTime, .denied: true
        default: false
        }
    }
}

/// The pasteboard privacy setting for PACE (macOS 15.4+).
public enum ClipboardPermission: Sendable {
    case allowed, asksEachTime, denied
}

/// What the app knows right now; nil clipboard means no clipboard store.
public struct PermissionFacts: Sendable {
    public var accessibility: Bool
    public var inputMonitoring: Bool
    public var autoExpandEnabled: Bool
    public var autoExpandRunning: Bool
    public var clipboard: ClipboardPermission?

    public init(accessibility: Bool, inputMonitoring: Bool, autoExpandEnabled: Bool, autoExpandRunning: Bool, clipboard: ClipboardPermission?) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
        self.autoExpandEnabled = autoExpandEnabled
        self.autoExpandRunning = autoExpandRunning
        self.clipboard = clipboard
    }
}

public struct PermissionRow: Equatable, Sendable, Identifiable {
    public let kind: PermissionKind
    public let state: PermissionState
    public var id: PermissionKind { kind }
}

public enum PermissionChecklist {
    /// One row per permission, always in the same order.
    public static func rows(_ facts: PermissionFacts) -> [PermissionRow] {
        PermissionKind.allCases.map { kind in
            PermissionRow(kind: kind, state: state(of: kind, facts))
        }
    }

    /// Input Monitoring was granted while auto-expand waits for it: worth
    /// one attempt to start it without a relaunch.
    public static func shouldRetryAutoExpand(_ facts: PermissionFacts) -> Bool {
        facts.autoExpandEnabled && facts.inputMonitoring && !facts.autoExpandRunning
    }

    private static func state(of kind: PermissionKind, _ facts: PermissionFacts) -> PermissionState {
        switch kind {
        case .accessibility:
            return facts.accessibility ? .granted : .missing
        case .inputMonitoring:
            guard facts.autoExpandEnabled else { return .notNeeded }
            // A running keyboard tap is what counts: it can run although
            // the preflight check says the permission is missing.
            if facts.autoExpandRunning { return .granted }
            return facts.inputMonitoring ? .needsRelaunch : .missing
        case .clipboard:
            switch facts.clipboard {
            case .allowed?: return .granted
            case .asksEachTime?: return .asksEachTime
            case .denied?: return .denied
            case nil: return .unavailable
            }
        case .automation:
            return .asksOnFirstUse
        }
    }
}
