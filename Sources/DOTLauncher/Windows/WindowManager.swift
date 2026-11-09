import AppKit
import ApplicationServices
import DOTLauncherCore

/// Moves and resizes other apps' windows through the Accessibility API.
final class WindowManager {
    private var history = RestoreHistory<String>()

    func perform(_ action: WindowAction, on target: NSRunningApplication?) {
        guard AccessibilityPermission.isGranted else {
            Log.windows.notice("\(action.title, privacy: .public) skipped: Accessibility is not granted")
            AccessibilityPermission.prompt()
            return
        }
        guard let app = target ?? NSWorkspace.shared.frontmostApplication else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // AX calls are synchronous IPC; don't let a hung app stall us for 6 s.
        AXUIElementSetMessagingTimeout(appElement, 0.5)

        guard let window = focusedWindow(of: appElement) else {
            Log.windows.notice("no window to move in \(app.bundleIdentifier ?? "?", privacy: .public)")
            return
        }
        if boolAttribute("AXFullScreen", of: window) == true {
            Log.windows.notice("skipped a full screen window")
            return
        }
        guard let primary = NSScreen.screens.first, let axFrame = frame(of: window) else { return }

        let primaryHeight = primary.frame.height
        let current = CoordinateSpace.appKitFrame(fromAX: axFrame, primaryScreenHeight: primaryHeight)
        let screens = NSScreen.screens
        let screen = screens[CoordinateSpace.bestScreenIndex(for: current, screens: screens.map(\.frame))]
        let key = "\(app.processIdentifier):\(CFHash(window))"

        let target: CGRect
        if action == .restore {
            guard let saved = history.take(for: key) else { return }
            target = saved
        } else {
            guard let frame = WindowGeometry.targetFrame(for: action, current: current, visibleFrame: screen.visibleFrame) else { return }
            history.remember(current, for: key)
            target = frame
        }

        setFrame(CoordinateSpace.axFrame(fromAppKit: target, primaryScreenHeight: primaryHeight), of: window, app: appElement)
        Log.windows.info("\(action.title, privacy: .public) → \(app.bundleIdentifier ?? "?", privacy: .public)")
    }

    // MARK: - AX helpers

    private func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        if let window = element(kAXFocusedWindowAttribute, of: app) { return window }
        if let window = element(kAXMainWindowAttribute, of: app) { return window }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }
        return windows.first
    }

    private func element(_ attribute: String, of parent: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func boolAttribute(_ attribute: String, of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position: CGPoint = axValue(kAXPositionAttribute, of: window, type: .cgPoint),
              let size: CGSize = axValue(kAXSizeAttribute, of: window, type: .cgSize)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func axValue<T>(_ attribute: String, of element: AXUIElement, type: AXValueType) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), type, pointer) else { return nil }
        return pointer.pointee
    }

    /// Position, then size, then position again: some apps clamp the size
    /// against the old position. Size is skipped for fixed-size windows.
    private func setFrame(_ frame: CGRect, of window: AXUIElement, app: AXUIElement) {
        // "Enhanced user interface" (set by some assistive tools) makes
        // Chrome and Electron animate every step; switch it off meanwhile.
        let enhanced = boolAttribute("AXEnhancedUserInterface", of: app) == true
        if enhanced {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }
        defer {
            if enhanced {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }

        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }

        var sizeSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        if sizeSettable.boolValue {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
    }
}
