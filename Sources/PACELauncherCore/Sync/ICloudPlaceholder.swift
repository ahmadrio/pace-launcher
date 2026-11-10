/// iCloud Drive replaces evicted files with a hidden stub named
/// `.<original name>.icloud` until the file is downloaded again.
public enum ICloudPlaceholder {
    private static let suffix = ".icloud"

    /// ".abc.md.icloud" -> "abc.md"; nil when not a placeholder.
    public static func originalName(of name: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(suffix), name.count > suffix.count + 1 else { return nil }
        return String(name.dropFirst().dropLast(suffix.count))
    }
}
