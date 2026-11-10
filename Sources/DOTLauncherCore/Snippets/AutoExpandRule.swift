/// Where auto-expand may run.
public enum AutoExpandRule {
    /// False inside DOT itself and in apps the user excluded. DOT's panels
    /// (launcher, notes, snippet editor) are non-activating, so the app
    /// behind them stays frontmost; a DOT window with keyboard focus counts
    /// as DOT too.
    public static func allows(frontmostBundleID: String?, dotIsFrontmost: Bool, dotHasKeyWindow: Bool, excluded: [String]) -> Bool {
        if dotIsFrontmost || dotHasKeyWindow { return false }
        return !excluded.contains(frontmostBundleID ?? "")
    }
}
