# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-11.md
Spec: docs/superpowers/specs/2026-11-10-tahap-11-design.md
Pre-flight: Task 1 → Task 2: SystemCommand (raw values = launcher command ids = CommandShortcut raw values) consumed by the catalog and runner — consistent. Task 3 independent.
Task 1: complete (commits 53e273a..62e894d, tests: make test → ✔ Test run with 353 tests in 63 suites passed after 0.605 seconds.)
Task 2: UI check (test folders, DOTSystemCommandDryRun): Start Screen Saver, Lock Screen and Sleep each logged "system command … (dry run)" and nothing ran; Log Out: one ↩ showed "Press ↩ again to log out" with no log line, a second ↩ logged it, and ↩ / 4 s / ↩ only showed the notice again; Settings › Shortcuts › Commands lists lock-screen, sleep, sleep-displays, screen-saver and no log-out. Dry-run flag deleted, app back on real data.
Task 2: complete (commits 62e894d..80d5d1e, tests: make test → ✔ Test run with 353 tests in 63 suites passed after 0.587 seconds.)
Task 3: note — the late-fallback path (launch error in NSWorkspace's completion handler) has no safe reproducer; verified by reading. The app-file check covers stale LaunchServices records.
Task 3: complete (commits 80d5d1e..84fc221, tests: make test → ✔ Test run with 355 tests in 64 suites passed after 0.602 seconds.)
Task 4: smoke on real data — "lock" → Lock Screen row first, "log out" → Log Out row first (nothing run; no dry-run or override keys set).
Task 4: complete (commits 84fc221..a6e6509, tests: make test → ✔ Test run with 355 tests in 64 suites passed after 0.609 seconds.)
Final review: fresh Opus reviewer — 2 Important, 8 Minor; ready to merge with fixes. Re-graded by effect:
Final: fixed after the first ↩ of a "press again" action the selection jumped to row 0, so the second ↩ could run another command (Important) — UI reproducer (test data): "test" → ↓ Confirm Test → ↩ moved the highlight to Local Test (RED); after keeping the row id across refresh the highlight stays on Confirm Test and the second ↩ ran it (GREEN); suite 356/356.
Final: fixed ⌃⌘Q/⇧⌘Q are the frontmost app's Apple-menu shortcuts and were lost while a DOT window held focus (Important) — DOT now hides and waits for focus to leave before posting, with a HUD if it cannot; UI (dry run, Settings focused): global ⌃⌥⌘9 and the launcher both logged "lock-screen (dry run, focus released: true)" and Warp became frontmost; real lock/log out never run.
Final: fixed ⌃⌘Q and ⇧⌘Q could be recorded as DOT shortcuts, so Lock bound to ⌃⌘Q would catch its own post forever (re-graded Important) — `the lock and log out combos are refused` RED→GREEN, suite 356/356.
Final: Ruling: the Accessibility message is a HUD, not model.notice as the plan said — `.run` has already closed the panel — cost if wrong: none.
Final: Ruling: system command rows are built in AppDelegate (needs the Log Out confirmation state and the HUD), not in CommandCatalog — cost if wrong: one more builder outside the catalog.
Final: Ruling: "phoenix" and "jersey" stay on the city-word list, so "5pm in phoenix" (worked on main) gives no row while "time in phoenix" works; "north"/"south" entries are no-ops — cost if wrong: Phoenix conversions need "time in phoenix" or "mst".
Final: minor (deferred): the Log Out arm is not reset when the query changes or the panel reopens (a ↩ within 3 s after reopening logs out without the notice; macOS's dialog still asks).
Final: minor (deferred): each arming press of Log Out records a use, inflating its rank.
Final: minor (deferred): a padded browser value (" com.apple.Safari ") is stored untrimmed and looks missing.
Final: minor (deferred): the late-fallback HUD claims the default browser opened without checking NSWorkspace's result.
Final: minor (deferred): with dry run but no Accessibility, the permission prompt still appears and nothing is logged.
Final: Ruling: Lock and Sleep run on one ↩ — the spec's decision — cost if wrong: a stray ↩ locks or sleeps the Mac (reversible).
Final: Ruling: apps that capture keystrokes (VMs, remote desktops) may swallow ⌃⌘Q/⇧⌘Q — the spec's mechanism — cost if wrong: nothing happens in those apps.
Final: Ruling: key code 12 is not Q on AZERTY/Dvorak — same caveat as ⌘V — cost if wrong: lock/log out post the wrong key there.
Final: Ruling: modifiers still held from the user's own shortcut may mix into the posted combo — untestable without locking — cost if wrong: an occasional wrong combo.
Final: Ruling: an app's own ⇧⌘Q binding may win over the Apple menu — depends on the app — cost if wrong: that app's command runs instead.
Final: Ruling: a browser reporting a launch error but opening anyway could open the link twice — no safe reproducer — cost if wrong: a duplicate tab.
Final: Ruling: Foundation's Process reaps pmset — no zombie — cost if wrong: none.
Final: Ruling: after reopening DOT from Finder, NSApp.hide may take longer than the wait — rare; the wait polls up to 1 s and falls back to a HUD — cost if wrong: a HUD instead of a lock.
