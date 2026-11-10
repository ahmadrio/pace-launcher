/// Where auto-expand may run.
public enum AutoExpandRule {
    /// False inside PACE itself and in apps the user excluded. PACE's panels
    /// (launcher, notes, snippet editor) are non-activating, so the app
    /// behind them stays frontmost; a PACE window with keyboard focus counts
    /// as PACE too.
    public static func allows(frontmostBundleID: String?, appIsFrontmost: Bool, appHasKeyWindow: Bool, excluded: [String]) -> Bool {
        if appIsFrontmost || appHasKeyWindow { return false }
        return !excluded.contains(frontmostBundleID ?? "")
    }
}
