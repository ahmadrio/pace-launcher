/// Schema migrations keyed on SQLite's `user_version`: step N is applied
/// once, when the stored version is below N + 1.
public enum Migrator {
    public static func migrate(_ db: SQLiteDatabase, steps: [String]) throws {
        let current = try db.userVersion()
        guard current < steps.count else { return }
        try db.transaction {
            for step in steps[current...] {
                try db.execute(step)
            }
            try db.setUserVersion(steps.count)
        }
    }
}
