import CoreGraphics
import Testing
@testable import DOTLauncherCore

/// A 1440×900 screen with a 25pt menu bar: AppKit visible frame.
private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

struct WindowGeometryTests {
    private func frame(_ action: WindowAction, current: CGRect = CGRect(x: 100, y: 100, width: 600, height: 400)) -> CGRect? {
        WindowGeometry.targetFrame(for: action, current: current, visibleFrame: visible)
    }

    @Test(arguments: [
        (WindowAction.leftHalf, CGRect(x: 0, y: 0, width: 720, height: 875)),
        (.rightHalf, CGRect(x: 720, y: 0, width: 720, height: 875)),
        (.topHalf, CGRect(x: 0, y: 438, width: 1440, height: 437)),
        (.bottomHalf, CGRect(x: 0, y: 0, width: 1440, height: 438)),
        (.maximize, CGRect(x: 0, y: 0, width: 1440, height: 875)),
    ])
    func `halves and maximize tile the visible frame`(action: WindowAction, expected: CGRect) {
        #expect(frame(action) == expected)
    }

    @Test(arguments: [
        (WindowAction.topLeft, CGRect(x: 0, y: 438, width: 720, height: 437)),
        (.topRight, CGRect(x: 720, y: 438, width: 720, height: 437)),
        (.bottomLeft, CGRect(x: 0, y: 0, width: 720, height: 438)),
        (.bottomRight, CGRect(x: 720, y: 0, width: 720, height: 438)),
    ])
    func `quarters use whole points and cover the screen`(action: WindowAction, expected: CGRect) {
        #expect(frame(action) == expected)
    }

    @Test func `centering keeps the size`() {
        #expect(frame(.center) == CGRect(x: 420, y: 238, width: 600, height: 400))
    }

    @Test func `centering shrinks a window larger than the screen`() {
        let huge = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        #expect(frame(.center, current: huge) == visible)
    }

    @Test func `almost maximize leaves a margin`() throws {
        let result = try #require(frame(.almostMaximize))
        #expect(result.width == 1296)
        #expect(result.height == 788)
        #expect(result.midX == visible.midX)
    }

    @Test func `works on a screen that is not at the origin`() {
        let secondary = CGRect(x: -1920, y: 200, width: 1920, height: 1055)
        let result = WindowGeometry.targetFrame(for: .rightHalf, current: .zero, visibleFrame: secondary)
        #expect(result == CGRect(x: -960, y: 200, width: 960, height: 1055))
    }

    @Test func `restore is not a geometry action`() {
        #expect(frame(.restore) == nil)
    }
}

struct CoordinateSpaceTests {
    /// Primary screen 1440×900 at the AppKit origin.
    let primaryHeight: CGFloat = 900

    @Test func `flips AppKit bottom-left to AX top-left`() {
        let appKit = CGRect(x: 0, y: 0, width: 100, height: 100)
        let ax = CoordinateSpace.axFrame(fromAppKit: appKit, primaryScreenHeight: primaryHeight)
        #expect(ax == CGRect(x: 0, y: 800, width: 100, height: 100))
    }

    @Test(arguments: [
        CGRect(x: 10, y: 20, width: 300, height: 200),
        CGRect(x: -1920, y: 200, width: 960, height: 1055),   // a screen to the left
        CGRect(x: 0, y: 900, width: 1440, height: 875),       // a screen above the primary
    ])
    func `round trips between AppKit and AX`(rect: CGRect) {
        let ax = CoordinateSpace.axFrame(fromAppKit: rect, primaryScreenHeight: primaryHeight)
        #expect(CoordinateSpace.appKitFrame(fromAX: ax, primaryScreenHeight: primaryHeight) == rect)
    }

    @Test func `a screen above the primary has negative AX y`() {
        let above = CGRect(x: 0, y: 900, width: 1440, height: 875)
        #expect(CoordinateSpace.axFrame(fromAppKit: above, primaryScreenHeight: primaryHeight).minY == -875)
    }

    @Test func `picks the screen with the largest overlap`() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        ]
        let window = CGRect(x: 1300, y: 100, width: 600, height: 400)   // mostly on the second
        #expect(CoordinateSpace.bestScreenIndex(for: window, screens: screens) == 1)
    }

    @Test func `falls back to the first screen when nothing overlaps`() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        let offscreen = CGRect(x: 5000, y: 5000, width: 10, height: 10)
        #expect(CoordinateSpace.bestScreenIndex(for: offscreen, screens: screens) == 0)
    }
}

struct RestoreHistoryTests {
    @Test func `remembers and returns the frame before the first snap`() {
        var history = RestoreHistory<Int>()
        let original = CGRect(x: 1, y: 2, width: 3, height: 4)

        history.remember(original, for: 7)
        history.remember(CGRect(x: 9, y: 9, width: 9, height: 9), for: 7)  // second snap keeps the original

        #expect(history.take(for: 7) == original)
        #expect(history.take(for: 7) == nil)
    }

    @Test func `forgets the oldest entries past its capacity`() {
        var history = RestoreHistory<Int>(capacity: 2)
        history.remember(.zero, for: 1)
        history.remember(.zero, for: 2)
        history.remember(.zero, for: 3)

        #expect(history.take(for: 1) == nil)
        #expect(history.take(for: 3) == .zero)
    }
}
