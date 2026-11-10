/// How an osascript run ended, from its exit status and error output.
public enum AppleScriptEnd: Equatable, Sendable {
    case done
    /// macOS refused the Apple Event: Automation is off for this app (-1743).
    case notPermitted
    /// The user pressed Cancel, e.g. in macOS's restart dialog (-128).
    case canceled
    /// The app took longer than the Apple Event timeout to answer (-1712);
    /// it may still be working (Finder emptying a large Trash).
    case timedOut
    /// Not started: the same command was still running.
    case alreadyRunning
    /// Anything else: osascript's last error line without its "12:40:
    /// execution error:" prefix (at most 120 characters), or the exit
    /// status when it printed nothing.
    case failed(String)

    public init(status: Int32, errorOutput: String) {
        if status == 0 {
            self = .done
        } else if errorOutput.contains("(-1743)") {
            self = .notPermitted
        } else if errorOutput.contains("(-128)") {
            self = .canceled
        } else if errorOutput.contains("(-1712)") {
            self = .timedOut
        } else {
            var line = errorOutput.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
            if let range = line.range(of: "execution error: ") { line = String(line[range.upperBound...]) }
            line = line.trimmingCharacters(in: .whitespaces)
            self = .failed(line.isEmpty ? "osascript exited with status \(status)" : String(line.prefix(120)))
        }
    }
}
