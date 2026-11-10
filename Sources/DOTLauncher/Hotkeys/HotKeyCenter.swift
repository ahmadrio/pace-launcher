import Carbon.HIToolbox
import DOTLauncherCore
import Observation

/// Registers global hotkeys through Carbon's RegisterEventHotKey.
///
/// Carbon hotkeys need no Accessibility permission and keep working while
/// Secure Input is on (unlike CGEventTaps).
@Observable
final class HotKeyCenter {
    enum Status: Equatable {
        case registered
        /// Registered alongside another app that also listens for the combo
        /// (macOS keeps ⌘Space even with Spotlight's shortcut off). Works,
        /// but that app may react too.
        case shared
        case unavailable(OSStatus)
        case disabled(String)
    }

    struct Entry {
        /// The ShortcutID raw value: unique, unlike titles.
        let name: String
        /// What menus show.
        let title: String
        let combo: KeyCombo
        var status: Status
    }

    private struct Registration {
        let combo: KeyCombo
        let ref: EventHotKeyRef?
        let action: () -> Void
    }

    private static let signature: OSType = 0x444F_544C // "DOTL"

    @ObservationIgnored private var registrations: [UInt32: Registration] = [:]
    @ObservationIgnored private var idsByName: [String: UInt32] = [:]
    @ObservationIgnored private var nextID: UInt32 = 1
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    /// What each named shortcut is set to and whether it works (observed
    /// by Settings).
    private(set) var entries: [Entry] = []

    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        if status != noErr {
            Log.hotkeys.error("InstallEventHandler failed: \(status)")
        }
    }

    /// Registers `combo` under `name` (a ShortcutID raw value), replacing
    /// any earlier registration with the same name. Returns the resulting status.
    @discardableResult
    func register(_ combo: KeyCombo, name: String, title: String, action: @escaping () -> Void) -> Status {
        unregister(name: name)

        if combo.conflicts(with: Self.enabledSystemShortcuts()) {
            Log.hotkeys.notice("\(title, privacy: .public) \(combo.displayString, privacy: .public) clashes with a system shortcut")
            return record(Entry(name: name, title: title, combo: combo, status: .unavailable(OSStatus(eventHotKeyExistsErr))))
        }

        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        var status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref
        )
        var shared = false
        if status == OSStatus(eventHotKeyExistsErr) {
            // Someone else listens for this combo without claiming it
            // exclusively (macOS does so for ⌘Space even when Spotlight's
            // shortcut is off). Listen alongside it instead of failing.
            status = RegisterEventHotKey(
                combo.keyCode, combo.carbonModifiers,
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(), 0, &ref
            )
            shared = status == noErr
        }

        guard status == noErr else {
            Log.hotkeys.notice("\(title, privacy: .public) \(combo.displayString, privacy: .public) not registered: \(status)")
            return record(Entry(name: name, title: title, combo: combo, status: .unavailable(status)))
        }

        registrations[id] = Registration(combo: combo, ref: ref, action: action)
        idsByName[name] = id
        Log.hotkeys.info("\(title, privacy: .public) registered as \(combo.displayString, privacy: .public)\(shared ? " (shared)" : "", privacy: .public)")
        return record(Entry(name: name, title: title, combo: combo, status: shared ? .shared : .registered))
    }

    /// Records a hotkey that is intentionally not registered, so the status
    /// menu can explain why.
    func markDisabled(_ combo: KeyCombo, name: String, title: String, reason: String) {
        unregister(name: name)
        record(Entry(name: name, title: title, combo: combo, status: .disabled(reason)))
    }

    func status(of name: String) -> Status? {
        entries.first { $0.name == name }?.status
    }

    func combo(of name: String) -> KeyCombo? {
        entries.first { $0.name == name }?.combo
    }

    /// Releases every shortcut, e.g. while Settings records a new one.
    func unregisterAll() {
        for name in entries.map(\.name) {
            unregister(name: name)
        }
    }

    func unregister(name: String) {
        if let id = idsByName.removeValue(forKey: name), let registration = registrations.removeValue(forKey: id) {
            UnregisterEventHotKey(registration.ref)
        }
        entries.removeAll { $0.name == name }
    }

    fileprivate func handle(id: UInt32) {
        guard let registration = registrations[id] else { return }
        Log.hotkeys.debug("pressed \(registration.combo.displayString, privacy: .public)")
        registration.action()
    }

    @discardableResult
    private func record(_ entry: Entry) -> Status {
        entries.removeAll { $0.name == entry.name }
        entries.append(entry)
        onChange?()
        return entry.status
    }

    /// Enabled system-wide shortcuts (Spotlight, input source switching, …).
    static func enabledSystemShortcuts() -> [KeyCombo] {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            return []
        }
        return array.compactMap { item in
            guard (item[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = item[kHISymbolicHotKeyCode as String] as? Int,
                  let modifiers = item[kHISymbolicHotKeyModifiers as String] as? Int
            else { return nil }
            return KeyCombo(keyCode: UInt32(code), carbonModifiers: UInt32(modifiers))
        }
    }
}

/// C callback for kEventHotKeyPressed. Handlers installed on the application
/// event target run on the main run loop, so asserting main-actor isolation
/// is safe here.
private nonisolated func hotKeyEventHandler(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }

    let id = hotKeyID.id
    // Raw pointers are not Sendable; pass the address instead. The
    // HotKeyCenter lives for the whole app, so the pointer stays valid.
    let address = UInt(bitPattern: userData)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<HotKeyCenter>.fromOpaque(pointer).takeUnretainedValue().handle(id: id)
    }
    return noErr
}
