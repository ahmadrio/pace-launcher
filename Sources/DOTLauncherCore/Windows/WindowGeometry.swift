import CoreGraphics

/// Target frames for window actions, in AppKit coordinates (origin at the
/// bottom left), within a screen's visible frame (no menu bar or Dock).
public enum WindowGeometry {
    /// Returns nil for actions that are not a fixed layout (restore).
    public static func targetFrame(for action: WindowAction, current: CGRect, visibleFrame vf: CGRect) -> CGRect? {
        // The left and bottom parts take the extra point of an odd size.
        let leftWidth = (vf.width / 2).rounded(.up)
        let rightWidth = vf.width - leftWidth
        let bottomHeight = (vf.height / 2).rounded(.up)
        let topHeight = vf.height - bottomHeight
        let midX = vf.minX + leftWidth
        let midY = vf.minY + bottomHeight

        let frame: CGRect
        switch action {
        case .leftHalf:
            frame = CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: vf.height)
        case .rightHalf:
            frame = CGRect(x: midX, y: vf.minY, width: rightWidth, height: vf.height)
        case .topHalf:
            frame = CGRect(x: vf.minX, y: midY, width: vf.width, height: topHeight)
        case .bottomHalf:
            frame = CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: bottomHeight)
        case .topLeft:
            frame = CGRect(x: vf.minX, y: midY, width: leftWidth, height: topHeight)
        case .topRight:
            frame = CGRect(x: midX, y: midY, width: rightWidth, height: topHeight)
        case .bottomLeft:
            frame = CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: bottomHeight)
        case .bottomRight:
            frame = CGRect(x: midX, y: vf.minY, width: rightWidth, height: bottomHeight)
        case .maximize:
            frame = vf
        case .almostMaximize:
            frame = centered(CGSize(width: vf.width * 0.9, height: vf.height * 0.9), in: vf)
        case .center:
            let size = CGSize(width: min(current.width, vf.width), height: min(current.height, vf.height))
            frame = centered(size, in: vf)
        case .restore:
            return nil
        }
        return frame.integralRounded
    }

    private static func centered(_ size: CGSize, in vf: CGRect) -> CGRect {
        CGRect(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2, width: size.width, height: size.height)
    }
}

extension CGRect {
    /// Rounds each component to the nearest whole point.
    var integralRounded: CGRect {
        CGRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }
}
