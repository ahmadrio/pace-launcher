import AppKit

/// The menu bar icon: the app icon's bold "P" with three speed lines, drawn as
/// a template image so macOS tints it for light and dark menu bars.
enum MenuBarIcon {
    static let size = NSSize(width: 21, height: 16)

    static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "PACE Launcher"
        return image
    }

    /// Draws the icon in black on a canvas of `size` points.
    static func draw(in context: CGContext) {
        let base = NSFont.systemFont(ofSize: 17, weight: .black)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 17) } ?? base
        var character: UniChar = 0x50 // "P"
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1),
              let letter = CTFontCreatePathForGlyph(font as CTFont, glyph, nil) else { return }
        // The letter sits on the right, centred vertically.
        let box = letter.boundingBoxOfPath
        let right = size.width - 0.5
        var place = CGAffineTransform(translationX: right - box.maxX, y: (size.height - box.height) / 2 - box.minY)
        context.setFillColor(NSColor.black.cgColor)
        if let placed = letter.copy(using: &place) {
            context.addPath(placed)
            context.fillPath()
        }
        // Speed lines trailing left from the stem, longest in the middle.
        let stem = right - box.width
        let thickness: CGFloat = 1.7
        let lines: [(offset: CGFloat, length: CGFloat)] = [(3.3, 5), (0, 7), (-3.3, 4)]
        for line in lines {
            let rect = CGRect(x: stem - line.length, y: size.height / 2 + line.offset - thickness / 2,
                              width: line.length + 1, height: thickness)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
            context.fillPath()
        }
    }
}
