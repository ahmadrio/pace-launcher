/// How an osascript run ended, from its exit status and error output.
public enum AppleScriptEnd: Equatable, Sendable {
    case done
    /// macOS refused the Apple Event: Automation is off for this app (-1743).
    case notPermitted
    /// The user pressed Cancel, e.g. in macOS's restart dialog (-128).
    case canceled
    /// Anything else, with osascript's last error line (at most 120 characters).
    case failed(String)

    public init(status: Int32, errorOutput: String) {
        if status == 0 {
            self = .done
        } else if errorOutput.contains("(-1743)") {
            self = .notPermitted
        } else if errorOutput.contains("(-128)") {
            self = .canceled
        } else {
            let line = errorOutput.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
            self = .failed(String(line.trimmingCharacters(in: .whitespaces).prefix(120)))
        }
    }
}
