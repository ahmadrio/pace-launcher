import AppKit

// Draws the GitHub social preview (1280×640) into the PNG path given as the first argument.
// Run from the repository root:
//   swiftc -O scripts/make-social-preview.swift -o /tmp/make-social-preview && /tmp/make-social-preview docs/images/social-preview.png
// Upload it in the repository's Settings › General › Social preview (GitHub has no API for it).
let width: CGFloat = 1280, height: CGFloat = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = CGRect(x: 0, y: 0, width: width, height: height)

// Background: the app icon's violet and indigo, darkened so white text reads well.
NSGradient(colors: [
    NSColor(srgbRed: 0.20, green: 0.12, blue: 0.48, alpha: 1),
    NSColor(srgbRed: 0.07, green: 0.05, blue: 0.18, alpha: 1),
])!.draw(in: canvas, angle: -35)
// A soft glow behind the screenshot, fading out completely.
let glowCenter = CGPoint(x: 920, y: 320)
NSGradient(colors: [
    NSColor(srgbRed: 0.55, green: 0.42, blue: 1.0, alpha: 0.30),
    NSColor(srgbRed: 0.55, green: 0.42, blue: 1.0, alpha: 0),
])!.draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: 460, options: [])

// Left column: icon, name, tagline, features, requirements.
let left: CGFloat = 80
if let icon = NSImage(contentsOfFile: "Resources/AppIcon.icns") {
    icon.draw(in: CGRect(x: left - 12, y: 432, width: 136, height: 136))
}
/// Draws a text block whose bottom edge is at `y`.
func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, at y: CGFloat, maxWidth: CGFloat = 520) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = size * 0.18
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .paragraphStyle: style,
    ]
    let block = NSAttributedString(string: string, attributes: attributes)
    let bounds = block.boundingRect(with: CGSize(width: maxWidth, height: 1000), options: [.usesLineFragmentOrigin])
    block.draw(with: CGRect(x: left, y: y, width: maxWidth, height: ceil(bounds.height)), options: [.usesLineFragmentOrigin])
}
text("PACE Launcher", size: 64, weight: .bold, alpha: 1, at: 340)
text("A free, open-source launcher for macOS", size: 28, weight: .medium, alpha: 0.88, at: 292)
text("Apps · Calculator · Clipboard history\nSnippets · Window snapping · Notes", size: 22, weight: .regular, alpha: 0.62, at: 196)
text("macOS 27 · Apple silicon · GPL-3.0", size: 18, weight: .medium, alpha: 0.5, at: 88)

// Right: the launcher, as in the README, with a shadow.
if let shot = NSImage(contentsOfFile: "docs/images/launcher.png") {
    let shotWidth: CGFloat = 600
    let shotHeight = shotWidth * shot.size.height / shot.size.width
    let frame = CGRect(x: 620, y: (height - shotHeight) / 2, width: shotWidth, height: shotHeight)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    shot.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
