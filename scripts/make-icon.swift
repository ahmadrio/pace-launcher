import AppKit

// Draws the PACE Launcher app icon at 1024×1024 into the PNG path given as the first argument.
// Rebuild Resources/AppIcon.icns: swiftc -O scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon icon.png, then sips into an .iconset and iconutil -c icns.
// A macOS-style squircle with a violet-to-indigo gradient, a bold white "P" and three speed lines.
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

// The body: 824 pt on Apple's 1024 grid, with continuous (superellipse) corners.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
func squircle(_ rect: CGRect, exponent n: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2, cx = rect.midX, cy = rect.midY
    for step in 0...720 {
        let t = CGFloat(step) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c >= 0 ? 1 : -1) * pow(abs(c), 2 / n)
        let y = cy + b * (s >= 0 ? 1 : -1) * pow(abs(s), 2 / n)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.line(to: CGPoint(x: x, y: y))
    }
    path.close()
    return path
}
let shape = squircle(body)

// Soft drop shadow, as macOS icons have.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor(srgbRed: 0.27, green: 0.20, blue: 0.75, alpha: 1).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

// Gradient fill: violet at the top left to deep indigo at the bottom right.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.55, green: 0.42, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.33, green: 0.25, blue: 0.93, alpha: 1),
    NSColor(srgbRed: 0.16, green: 0.11, blue: 0.55, alpha: 1),
], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
gradient.draw(in: body, angle: -55)
// A faint top highlight for depth.
let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
highlight.draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// The "P": SF Pro Rounded, black weight, white.
let font = NSFont.systemFont(ofSize: 600, weight: .black)
let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 600) } ?? font
let letter = NSAttributedString(string: "P", attributes: [.font: rounded, .foregroundColor: NSColor.white])
let bounds = letter.boundingRect(with: .zero, options: [.usesLineFragmentOrigin, .usesFontLeading])
let glyphWidth = letter.size().width
let origin = CGPoint(x: body.midX - glyphWidth / 2 + 60, y: body.midY - bounds.height / 2 + 10)
NSGraphicsContext.saveGraphicsState()
let glyphShadow = NSShadow()
glyphShadow.shadowColor = NSColor(srgbRed: 0.08, green: 0.04, blue: 0.35, alpha: 0.45)
glyphShadow.shadowBlurRadius = 18
glyphShadow.shadowOffset = NSSize(width: 0, height: -8)
glyphShadow.set()
letter.draw(at: origin)

// Three speed lines trailing to the left of the stem, longest in the middle.
let lines: [(y: CGFloat, length: CGFloat, alpha: CGFloat)] = [(612, 150, 0.85), (512, 210, 1.0), (412, 120, 0.7)]
for line in lines {
    let right = origin.x + 40
    let rect = CGRect(x: right - line.length, y: line.y - 22, width: line.length, height: 44)
    NSColor.white.withAlphaComponent(line.alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22).fill()
}
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
_ = context
