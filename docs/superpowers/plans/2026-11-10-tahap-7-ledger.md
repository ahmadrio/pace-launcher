# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-7.md
Spec: docs/superpowers/specs/2026-11-10-tahap-7-design.md
Pre-flight:
- Task 2 → Task 3: Quicklink.{url(for:), takesQuery, defaults}, Quicklinks.match, SettingsData.quicklinks; Task 3 consumes the same names — consistent.
- Task 2 → Task 4: Quicklinks.problem(with:existing:) and SettingsData.quicklinks; Task 4's editor consumes them — consistent.
- Task 5: ScriptShortcut rows/fingerprint are local to Task 5 (Core + app) — no cross-task conflict.
Task 1: note — `copied results keep no grouping` passed before the change: it pins the unchanged copy format (Review Focus 5).
Task 1: complete (commits 8decd1e..38d97f9, tests: make test → ✔ Test run with 303 tests in 54 suites passed after 0.614 seconds.)
Task 2: complete (commits 38d97f9..daecc4a, tests: make test → ✔ Test run with 310 tests in 55 suites passed after 0.596 seconds.)
Task 3: Ruling: UI checks open quicklinks to a scratch URL-catcher app (scheme dott7://, registered from ~/Library/Caches/dot-launcher-tests because LaunchServices will not bind apps in a temp dir) instead of the plan's file:// page — no browser tab is opened on Pace's Mac and the exact URL handed to NSWorkspace is recorded — cost if wrong: none for coverage; the catcher must be removed and unregistered at wrap-up.
Task 3: UI check (test folders): `lt hello & bye` → first row "Search Local Test for “hello & bye”", ⏎ opened dott7://search?q=hello%20%26%20bye; `gh` alone → GitHub as a normal row, no inline row; "Local Test" → quicklink mode, `x y` ⏎ → dott7://search?q=x%20y; mode + `z` + Esc → back at root, nothing opened; "Catcher Home" → dott7://home. App back on real data.
Task 3: complete (commits daecc4a..d40f0f8, tests: make test → ✔ Test run with 310 tests in 55 suites passed after 0.571 seconds.)
Task 4: UI check (test folders): "Create Quicklink" opened Settings › Quicklinks with the form; Wiki + keyword "G" → "Another quicklink uses this keyword."; URL "wikipedia.org" → the full-URL message; valid URL saved (settings.json lists Wiki/wk, launcher row "Wiki · wk · en.wikipedia.org"); Delete removed it from both. AX `set value` does not reach SwiftUI TextField bindings, so the fields were typed through a guard that checks NSWorkspace's frontmost app is DOT and the field has focus. App back on real data.
Task 4: complete (commits d40f0f8..e3f952a, tests: make test → ✔ Test run with 310 tests in 55 suites passed after 0.591 seconds.)
Task 5: UI check (test folders, log stream): late.sh created with the panel closed → "Late Test registered as ⌃⌥⌘7" within 3 s and its HUD "Late arrived"; opening/closing the panel twice added no "registered" lines (9 → 9); ↩ on Confirm Test armed the launcher ("Press ↩ again…"), then one ⌃⌥⌘4 press only showed "Press ⌃⌥⌘4 again…" and did not run (no marker). App back on real data.
Task 5: complete (commits e3f952a..8bf36cf, tests: make test → ✔ Test run with 312 tests in 55 suites passed after 1.064 seconds.)
Task 6: UI check (test folders): 3 clips aged 30 days → "1 week" → alert "Delete 3 clips?" → Delete (now passing the presented value) → picker 1 week, clips removed; Forever applied with no alert. App back on real data. The count-failure path has no reproducer (it needs a SQLite error); covered by reading only.
Task 6: complete (commits 8bf36cf..cd7d7cc, tests: make test → ✔ Test run with 313 tests in 55 suites passed after 0.590 seconds.)
Task 7: smoke on real data — 1500000+1 shows 1.500.001; gh test shows "Search GitHub for “test”" (not opened); Settings › Quicklinks lists the four defaults (AX read); Pace's settings.json was not rewritten (no quicklinks key, mtime unchanged). URL catcher unregistered and deleted.
Task 7: complete (commits cd7d7cc..4dcd526, tests: make test → ✔ Test run with 313 tests in 55 suites passed after 0.596 seconds.)
Final review: fresh Opus reviewer — no Critical/Important as labelled, 9 Minor; ready to merge. Re-graded by effect:
Final: fixed shortcuts that macOS refused (e.g. ⌘Space while Spotlight's shortcut is on) were never retried after the fingerprint gate (re-graded Important: regression of this branch, can hit the launcher shortcut) — `shortcuts are retried while one could not be registered` RED→GREEN, suite 315/315. UI: an exclusive holder only makes DOT register as "shared", so the refused case needs a macOS shortcut conflict; not reproduced on Pace's system settings.
Final: fixed a bare default keyword ("g", "gh", "yt") lifted the quicklink above the app usually found with it (re-graded Important: the spec's anti-goal) — `a bare keyword does not lift a quicklink above a used app` RED→GREEN, suite 315/315. UI on real data: `g` → Google Chrome first.
Final: Ruling: HANDOFF errors (#9: tahap-6 lines under tahap 7, stale "no folder watching" text) fixed in the fix pass — Task 7's own deliverable — cost if wrong: none.
Final: minor (deferred): hand-written settings.json quicklinks without an `id` are skipped and dropped on the next save; duplicate ids make Delete remove both and show rows twice.
Final: minor (deferred): the quicklink form stays open after Settings closes; a stale edit can overwrite a newer synced link or re-add a deleted one; "Create Quicklink" discards an open edit.
Final: minor (deferred): a main Scripts folder that appears after launch (iCloud on a second Mac, made in Finder) is not watched until the launcher or Settings opens.
Final: minor (deferred): FSEvents reloads also fire for hidden or too-deep changes (e.g. .git) the scanner ignores, rescanning on the main thread.
Final: minor (deferred): strict URL parsing refuses non-ASCII hosts/paths and `|` that browsers accept (bücher.de, søk).
Final: minor (deferred): settings.json escapes slashes in URLs (missing .withoutEscapingSlashes).
Final: Ruling: Indian-style grouping (en_IN 15,00,000) not done — plan specifies groups of three; Pace's locale is en_ID — cost if wrong: en_IN users see western grouping.
Final: Ruling: floating-point noise such as 12.345.678,9000000004 — pre-existing `format` (%.10f) — stands — cost if wrong: an odd long decimal now and then.
Final: Ruling: settings.json edits are not picked up while DOT runs — pre-existing — stands — cost if wrong: hand edits need a relaunch.
Final: Ruling: an older DOT on another synced Mac can drop the `quicklinks` key on save — version mismatch is outside this spec — cost if wrong: custom quicklinks fall back to the defaults.
Final: Ruling: ⏎ in the same run-loop turn as the last keystroke in quicklink mode could use the previous text — shared async pattern of every list mode, not reachable by typing — cost if wrong: a stale query once in a while.
Final: Ruling: `javascript:` and any named scheme are accepted — the spec allows any scheme; NSWorkspace refuses ones nothing handles — cost if wrong: a saved quicklink can launch any app that registers its scheme.
Final: Ruling: `yt music` shows the inline row above an app named "YT Music" — an exact keyword with text wins by design — cost if wrong: one extra ↓.
Final: Ruling: no global shortcut for "Create Quicklink" and the form opens without focus in Name — not in the spec — cost if wrong: one extra click.
