import CoreText
import Foundation

// Writes the emoji the picker cannot build from Swift's Unicode properties:
// multi-code-point sequences (ZWJ, keycaps, tag flags), from Unicode's
// emoji-test.txt. Download the file first (the version Apple's emoji font
// draws; check with this script, which refuses sequences it cannot draw):
//
//   curl -o emoji-test.txt https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt
//   swift scripts/make-emoji-data.swift emoji-test.txt
//
// Output:
//   Sources/PACELauncherCore/Emoji/EmojiSequences.swift  the sequences
//   Tests/PACELauncherCoreTests/UnicodeEmojiList.swift    every emoji, for tests

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift scripts/make-emoji-data.swift <emoji-test.txt>\n".data(using: .utf8)!)
    exit(2)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

guard let text = try? String(contentsOfFile: arguments[1], encoding: .utf8) else { fail("cannot read \(arguments[1])") }
guard let versionLine = text.split(separator: "\n").first(where: { $0.hasPrefix("# Version:") }) else { fail("no '# Version:' line") }
let version = versionLine.dropFirst("# Version:".count).trimmingCharacters(in: .whitespaces)

struct Entry {
    let scalars: [UInt32]
    let name: String
}

let skinTones: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF
let medium: UInt32 = 0x1F3FD
var bases: [Entry] = []
var mediums: [Entry] = []
for line in text.split(separator: "\n") {
    let parts = line.split(separator: ";", maxSplits: 1)
    guard parts.count == 2, parts[1].contains("fully-qualified"),
          let hash = parts[1].firstIndex(of: "#")
    else { continue }
    let scalars = parts[0].split(separator: " ").compactMap { UInt32($0, radix: 16) }
    // "# 🧑‍💻 E12.1 technologist": the name follows the version.
    let comment = parts[1][parts[1].index(after: hash)...].split(separator: " ", maxSplits: 2)
    guard comment.count == 3 else { fail("unreadable line: \(line)") }
    let entry = Entry(scalars: scalars, name: String(comment[2]))
    let tones = scalars.filter { skinTones.contains($0) }
    if tones.isEmpty {
        bases.append(entry)
    } else if tones.allSatisfy({ $0 == medium }) {
        mediums.append(entry)
    }
}
guard bases.count > 1000 else { fail("only \(bases.count) emoji found") }

/// Without variation selectors and skin tones: a toned form and its base agree.
func key(_ scalars: [UInt32]) -> [UInt32] {
    scalars.filter { $0 != 0xFE0F && !skinTones.contains($0) }
}

var baseByKey: [[UInt32]: Int] = [:]
for (index, base) in bases.enumerated() {
    if baseByKey.updateValue(index, forKey: key(base.scalars)) != nil { fail("two emoji share \(hex(base.scalars))") }
}
var template: [Int: [UInt32]] = [:]
var orphans: [String] = []
for entry in mediums {
    guard let index = baseByKey[key(entry.scalars)] else {
        orphans.append(entry.name)
        continue
    }
    template[index] = entry.scalars
}
let matchedMediums = mediums.filter { baseByKey[key($0.scalars)] != nil }

func hex(_ scalars: [UInt32]) -> String {
    scalars.map { String(format: "%04X", $0) }.joined(separator: " ")
}

func string(_ scalars: [UInt32]) -> String {
    var view = String.UnicodeScalarView()
    for value in scalars { view.append(Unicode.Scalar(value)!) }
    return String(view)
}

/// Sequences joined by ZWJ, keycaps and tag flags. Single code points (with
/// or without U+FE0F) and country flags come from Swift and the region list.
func isSequence(_ scalars: [UInt32]) -> Bool {
    scalars.contains { $0 == 0x200D || $0 == 0x20E3 || (0xE0020...0xE007F).contains($0) }
}

// Every sequence and every toned form must be one emoji wide in Apple's
// font: a font that lacks one draws its parts side by side (👯 + a 🏽
// swatch). Couples are two layered glyphs, so compare widths rather than
// counting glyphs. (A font may also drop a tone silently: 👪🏽 draws as 👪,
// but so do 🏂🏽 and 🛌🏽 by design, so same-glyph is not a failure.)
let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 32, nil)
// CoreText falls back to another font for an unknown name; measuring that
// one would pass everything.
guard CTFontCopyPostScriptName(font) as String == "AppleColorEmoji" else { fail("Apple Color Emoji font not found") }
func width(_ text: String) -> Double {
    let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
}
let emojiWidth = width("😀")
let sequenceIndexes = bases.indices.filter { isSequence(bases[$0].scalars) }
let undrawn = (sequenceIndexes.map { bases[$0].scalars } + matchedMediums.map(\.scalars))
    .filter { abs(width(string($0)) - emojiWidth) > 0.5 }
guard undrawn.isEmpty else {
    fail("Apple Color Emoji cannot draw \(undrawn.count) emoji, e.g. \(undrawn.prefix(5).map { string($0) }); use an older emoji-test.txt")
}

let packageRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

var sequences = "// Generated by scripts/make-emoji-data.swift from Unicode emoji-test.txt \(version). Do not edit.\n\n"
sequences += "extension EmojiCatalog {\n"
sequences += "    /// Emoji made of several code points, in emoji-test order: code points;\n"
sequences += "    /// CLDR name; and, when Unicode gives every person one skin tone, that\n"
sequences += "    /// form in medium tone (U+1F3FD marks where a tone goes).\n"
sequences += "    static let sequenceData = #\"\"\"\n"
for index in sequenceIndexes {
    let base = bases[index]
    sequences += "    \(hex(base.scalars));\(base.name)" + (template[index].map { ";" + hex($0) } ?? "") + "\n"
}
sequences += "    \"\"\"#\n}\n"

var list = "// Generated by scripts/make-emoji-data.swift from Unicode emoji-test.txt \(version). Do not edit.\n\n"
list += "/// Every fully-qualified emoji in Unicode \(version) without skin tones, and\n"
list += "/// every form with one medium tone throughout, as code points per line.\n"
list += "enum UnicodeEmojiList {\n"
list += "    static let version = \"\(version)\"\n\n"
list += "    static let base = \"\"\"\n"
for base in bases { list += "    \(hex(base.scalars))\n" }
list += "    \"\"\"\n\n"
list += "    static let medium = \"\"\"\n"
for entry in matchedMediums { list += "    \(hex(entry.scalars))\n" }
list += "    \"\"\"\n}\n"

do {
    try sequences.write(to: packageRoot.appending(path: "Sources/PACELauncherCore/Emoji/EmojiSequences.swift"), atomically: true, encoding: .utf8)
    try list.write(to: packageRoot.appending(path: "Tests/PACELauncherCoreTests/UnicodeEmojiList.swift"), atomically: true, encoding: .utf8)
} catch {
    fail("cannot write: \(error)")
}
print("Unicode \(version): \(bases.count) emoji, \(sequenceIndexes.count) sequences (\(sequenceIndexes.filter { template[$0] != nil }.count) take a skin tone), \(matchedMediums.count) medium-tone forms")
if !orphans.isEmpty {
    print("medium-tone forms with no untoned base (skipped): \(orphans.joined(separator: ", "))")
}
