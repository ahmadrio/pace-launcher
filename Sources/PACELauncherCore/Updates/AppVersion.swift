/// A release version like 1.2.3, read from a tag ("v1.2.3") or from
/// CFBundleShortVersionString. Anything else (pre-release suffixes, extra
/// parts, non-ASCII digits) is not a version.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    /// One to three dot-separated groups of ASCII digits, optionally after
    /// a "v"; missing groups are 0.
    public init?(_ text: String) {
        var rest = Substring(text)
        if rest.first == "v" || rest.first == "V" { rest = rest.dropFirst() }
        let groups = rest.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(groups.count) else { return nil }
        var numbers: [Int] = []
        for group in groups {
            guard !group.isEmpty, group.count <= 9,
                  group.unicodeScalars.allSatisfy({ ("0"..."9").contains($0) }),
                  let number = Int(group)
            else { return nil }
            numbers.append(number)
        }
        while numbers.count < 3 { numbers.append(0) }
        major = numbers[0]
        minor = numbers[1]
        patch = numbers[2]
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
