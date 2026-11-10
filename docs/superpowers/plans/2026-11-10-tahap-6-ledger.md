# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-6.md
Spec: docs/superpowers/specs/2026-11-10-tahap-6-design.md
Pre-flight:
- Task 3 → Task 4: produces ShortcutID.script(String) + Shortcuts.resolve with script keys; Task 4 consumes both for rows — consistent.
- Task 3/4 → Task 5: Group.scripts (order launcher, commands, scripts, window) and ScriptShortcut.{key, script(forKey:), step, rows}; Task 5 consumes the same names — consistent.
- Task 1 → Task 2: both edit Converter.swift (amount vs ConversionFormat), no shared signature — no conflict.
- Task 4 rows detail = folder name; Task 5 UI check expects "Scripts"/"sub" — consistent.
Task 1: note: `shorthand needs a whole word` passed before implementation — it guards unchanged behaviour (10kg, 2 e, 10 kb), as the brief intends.
Task 1: complete (commits d3521cd..c164a05, tests: make test → ✔ Test run with 274 tests in 48 suites passed after 0.575 seconds.)
Task 2: UI check — 1 idr to usd shows "0,0000553 USD"; local listener saw Accept-Language: en and User-Agent: DOTLauncher. App back on real data.
Task 2: complete (commits c164a05..5640154, tests: make test → ✔ Test run with 276 tests in 48 suites passed after 0.579 seconds.)
Task 3: complete (commits 5640154..94ca11f, tests: make test → ✔ Test run with 283 tests in 48 suites passed after 0.589 seconds.)
Task 4: complete (commits 94ca11f..c104e24, tests: make test → ✔ Test run with 289 tests in 49 suites passed after 0.586 seconds.)
Task 5: UI check (test folders): both "Hello" scripts registered and showed their HUDs; ⌃⌥⌘3 showed output in the panel; ⌃⌥⌘4 ran only on the second press (marker file); ⌃⌥⌘5 opened the arguments form; Settings › Shortcuts › Scripts listed Hello (Scripts) / Hello (sub) and gone.sh "Not found on this Mac" with a disabled record button; creating gone.sh + opening the panel registered ⌃⌥⌘6. App back on real data.
Task 5: complete (commits c104e24..ff60ce9, tests: make test → ✔ Test run with 289 tests in 49 suites passed after 0.585 seconds.)
Task 6: incident — during the AI UI check DOT's panel had closed; my script still sent ⌘N + an Indonesian prompt + Return, which went to Warp (frontmost): a new Warp window titled with that prompt. Left untouched (could not safely tell it from this session's window); to report to Pace. From now on keystrokes go through a guard that checks DOT has keyboard focus.
Task 6: UI check (test folders): a chat opened from AI Chats mid-answer showed its partial answer at once and stayed stopped. Esc sent the moment "Translating…" appeared (OCR watcher): the Translation framework did not stop on cancel, so the answer finished in Indonesian with no error and was saved (chat listed with 6 messages). The throwing path (cancel/failure during translation) is covered by ChatRunEnd tests only.
Task 6: note — `cancelling the question translation stops quietly` passed against the stub (the stub returned exactly that value); the other three ChatRunEnd tests failed first.
Task 6: complete (commits ff60ce9..619fd2c, tests: make test → ✔ Test run with 293 tests in 50 suites passed after 0.587 seconds.)
Task 7: note — `pruning keeps a pinned image clip's files` passed before any change: it adds coverage for correct behaviour (the deferred minor was the missing check).
Task 7: UI check (test folders): 3 clips aged 30 days → "1 week" showed "Delete 3 clips?"; Cancel kept Forever and the clips; Delete set "week" and removed them; Forever applied with no alert. A test PNG pasted from Clipboard History into a TextEdit doc; the pasteboard listed public.png + public.tiff and the TIFF (962 KB, made on request) decoded. Pace's clipboard snapshot restored, hash d83b9d5b… matches. App back on real data.
Task 7: complete (commits 619fd2c..378b234, tests: make test → ✔ Test run with 297 tests in 51 suites passed after 0.622 seconds.)
Task 8: Ruling: copy the ledger to docs/ after the final review instead of in this task — so the copy includes the Final lines — cost if wrong: none (one extra copy).
Task 8: smoke on real data — 1jt idr to usd = 55,3 USD; 1jt + 500rb = 1500000; Settings › Shortcuts › Scripts shows the empty note (Pace has no scripts); status menu "Open DOT Launcher ⌘Space"; no iCloud DOT folder (none before either).
Task 8: complete (commits 378b234..dbff6d2, tests: make test → ✔ Test run with 297 tests in 51 suites passed after 0.612 seconds.)
Final review: fresh Opus reviewer — no Critical/Important as labelled, 8 Minor; ready to merge. Re-graded by effect:
Final: fixed Esc during "Translating…" did not stop and `open()` waited for the whole translation (re-graded Important: spec item unobservable + new wait) — `prose is translated paragraph by paragraph and code is kept`, `translation stops before the next paragraph once cancelled` RED→GREEN, suite 301/301. UI: Esc at "Translating…" stopped within ~1 s, English answer shown and saved (original NULL).
Final: fixed DOT's clipboard snapshot built the lazy TIFF in the middle of a paste and restored it eagerly (re-graded Important: regression of this branch in the auto-expand/snippet path) — `a TIFF next to a PNG is skipped and offered again lazily` RED→GREEN, suite 301/301. UI: image pasted from history, then a snippet pasted → clipboard restored with PNG + TIFF that decodes; Pace's clipboard restored, hash d83b9d5b… matches.
Final: Ruling: stale HANDOFF line about shorthand (#8) fixed in the fix pass — it is Task 8's own deliverable, not polish — cost if wrong: none.
Final: Ruling: a missing script's shortcut comes back on the next script reload (launcher or Settings opened), not by watching folders; HANDOFF says so — the spec's "otomatis" holds without touching the shortcut, but not instantly — cost if wrong: a script restored by iCloud stays inactive until the launcher is opened once.
Final: minor (deferred): a missing script's shortcut gives no feedback when pressed (not registered), and there is no folder watching.
Final: minor (deferred): applyShortcuts runs on every panel open via scriptLibrary.onChange — gated entries are re-marked (status submenu reorders) and unavailable ones are retried with a log line.
Final: minor (deferred): the launcher ↩ confirmation and the script shortcut share one PressConfirmation, so ↩ then the shortcut within 3 s runs the script.
Final: minor (deferred): the retention alert relies on SwiftUI running the button action before the isPresented setter; a failed count applies the shorter retention without asking.
Final: minor (deferred): duplicate-title rows show only the parent folder name (can be ambiguous across folders), and tie order comes from dictionary order.
Final: Ruling: Carbon hotkey auto-repeat — Carbon hot keys fire kEventHotKeyPressed once per press; the UI check pressed the confirmation shortcut once and it did not run — stands — cost if wrong: holding the shortcut could confirm.
Final: Ruling: pasteboardFinishedWithDataProvider uses MainActor.assumeIsolated — AppKit calls pasteboard providers on the main thread; two UI checks exercised it without a crash — stands — cost if wrong: a crash if AppKit ever calls it off the main thread.
Final: Ruling: "Remove" on a "Not found on this Mac" row removes the key from the synced settings.json for every Mac — spec design (settings sync) — stands — cost if wrong: an extra-folder shortcut made on another Mac is lost there too.
Final: Ruling: hand-edited duplicate combos for two ids — the second registration fails or shares and Settings shows its status — stands — cost if wrong: one of the two does not fire.
Final: Ruling: ScriptScanner reads scripts on the main thread at launch and on each script shortcut press — pre-existing scanner, sync off by default — stands — cost if wrong: a hitch when iCloud has evicted script files.
Final: Ruling: `Tb` = terabit and `1k to usd` read as kelvin — spec decisions ("units win") — stand — cost if wrong: a surprising row for those inputs.
Final: Ruling: a background-mode script shortcut closes an open launcher panel — same as running it from the launcher — stands — cost if wrong: the panel closes unexpectedly.
Final: Ruling: an empty "done" bubble after cancelling during the question translation — pre-existing, harmless — stands — cost if wrong: Copy Answer copies empty text.
