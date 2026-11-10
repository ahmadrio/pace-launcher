import CoreGraphics

/// AppKit puts the origin at the bottom left of the primary screen with y
/// growing upward; the Accessibility API puts it at the top left with y
/// growing downward. Both share x.
public enum CoordinateSpace {
    public static func axFrame(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func appKitFrame(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Index of the screen frame that overlaps `window` the most, or 0.
    public static func bestScreenIndex(for window: CGRect, screens: [CGRect]) -> Int {
        var best = 0
        var bestArea: CGFloat = 0
        for (index, screen) in screens.enumerated() {
            let overlap = screen.intersection(window)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                best = index
                bestArea = area
            }
        }
        return best
    }
}
