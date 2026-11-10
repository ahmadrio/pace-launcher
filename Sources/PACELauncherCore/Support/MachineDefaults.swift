/// UserDefaults keys for state that belongs to this Mac (first launch,
/// update checks). While test data folders are in use, they get their own
/// keys, so a test run never uses up the real first launch.
public enum MachineDefaults {
    public static func key(_ base: String, usingTestFolders: Bool) -> String {
        usingTestFolders ? base + ".testData" : base
    }
}
