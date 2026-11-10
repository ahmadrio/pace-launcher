import AppKit

/// The menu bar icon: the app icon's bold "P" with three speed lines, drawn as
/// a template image so macOS tints it for light and dark menu bars.
/// AppKit may run an image's drawing handler on any thread, so the drawing
/// is nonisolated and uses only fonts and Core Graphics.
enum MenuBarIcon {
    /// The letter is as tall as other apps' menu bar icons (16–17 pt).
    nonisolated static let letterHeight: CGFloat = 16
    nonisolated static let size = NSSize(width: 24, height: 18)

    static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { @Sendable _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "PACE Launcher"
        return image
    }

    /// Draws the icon in black on a canvas of `size` points.
    nonisolated static func draw(in context: CGContext) {
        // The outline of the 17 pt letter the icon was designed with, scaled up.
        let base = NSFont.systemFont(ofSize: 17, weight: .black)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 17) } ?? base
        var character: UniChar = 0x50 // "P"
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1),
              let letter = CTFontCreatePathForGlyph(font as CTFont, glyph, nil) else { return }
        // The letter, scaled to letterHeight, sits on the right, centred vertically.
        let box = letter.boundingBoxOfPath
        let scale = letterHeight / box.height
        let right = size.width - 0.5
        var place = CGAffineTransform(
            translationX: right - box.maxX * scale,
            y: (size.height - letterHeight) / 2 - box.minY * scale
        ).scaledBy(x: scale, y: scale)
        context.setFillColor(NSColor.black.cgColor)
        if let placed = letter.copy(using: &place) {
            context.addPath(placed)
            context.fillPath()
        }
        // Speed lines trailing left from the stem, longest in the middle.
        // Their measures were drawn for a 12 pt letter and scale with it.
        let unit = letterHeight / 12
        let stem = right - box.width * scale
        let thickness = 1.7 * unit
        let lines: [(offset: CGFloat, length: CGFloat)] = [(3.3, 5), (0, 7), (-3.3, 4)]
        for line in lines {
            let rect = CGRect(x: stem - line.length * unit, y: size.height / 2 + line.offset * unit - thickness / 2,
                              width: (line.length + 1) * unit, height: thickness)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
            context.fillPath()
        }
    }
}
