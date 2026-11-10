import AppKit
import CoreGraphics

/// A listen-only keyboard and mouse event tap. It never changes or blocks
/// events; it only reports typed text, deletions, and moments when the
/// typing context resets (clicks, arrows, shortcuts).
final class KeystrokeMonitor {
    var onText: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onReset: () -> Void = {}

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Shows the system prompt for Input Monitoring (once per app).
    static func requestPermission() {
        _ = CGRequestListenEventAccess()
    }

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Starts the tap; false when permission is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: keystrokeTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.app.notice("keystroke tap unavailable (Input Monitoring not granted)")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func handle(_ event: TapEvent) {
        switch event {
        case .reenable:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .reset: onReset()
        case .delete: onDelete()
        case .text(let text): onText(text)
        case .ignore: break
        }
    }
}

/// What a tapped event means for keyword matching (Sendable, unlike CGEvent).
private enum TapEvent: Sendable {
    case text(String), delete, reset, reenable, ignore
}

private nonisolated func classify(_ type: CGEventType, _ event: CGEvent) -> TapEvent {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        return .reenable
    case .leftMouseDown, .rightMouseDown:
        return .reset
    case .keyDown:
        // Ignore what PACE itself posts (the backspaces and ⌘V of an expansion).
        if event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(getpid()) { return .ignore }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return .reset
        }
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 51: return .delete
        case 36, 48, 53, 76, 123, 124, 125, 126, 115, 119, 116, 121: return .reset   // return, tab, esc, enter, arrows, home/end, page
        default:
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &characters)
            let text = String(utf16CodeUnits: characters, count: length)
            guard !text.isEmpty, text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
                return .ignore
            }
            return .text(text)
        }
    default:
        return .ignore
    }
}

/// Event taps on the main run loop call back on the main thread.
private nonisolated func keystrokeTapCallback(
    _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let address = UInt(bitPattern: userInfo)
        let meaning = classify(type, event)
        MainActor.assumeIsolated {
            guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
            Unmanaged<KeystrokeMonitor>.fromOpaque(pointer).takeUnretainedValue().handle(meaning)
        }
    }
    return Unmanaged.passUnretained(event)
}
