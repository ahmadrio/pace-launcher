# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-19.md
Spec: docs/superpowers/specs/2026-11-10-tahap-19-design.md
Pre-flight: Task 1 produces ScriptRunQueue (submit/finish/isRunning), SystemCommand.queuesRepeatRuns, AppleScriptEnd.alreadyRunning; Task 2 consumes them by the same names — consistent.
Task 1: Ruling: the `.alreadyRunning` HUD case in AppDelegate (planned for Task 2) went into Task 1 — the new enum case made its switch non-exhaustive — cost if wrong: none.
Task 1: complete (commits 9132bf0..76cdeb0, tests: make test → ✔ Test run with 377 tests in 66 suites passed after 0.627 seconds.)
Task 2: UI check (test folders):
  `tema` → first row "Appearance Settings · Theme, accent colour, glass, light or dark"; ↩ → Settings opened on Appearance (Theme, Accent color, Glass density, Mode); closed via its close button.
  Notes ("Open Notes") and the snippet editor ("Create Snippet"), captured per window with `screencapture -l <CGWindowID>` while DOT was active (they hide when DOT is inactive), luminance: Dark notes 44 / snippet 61 → Light (switched with DOT's Toggle Dark Mode) 255 / 241 → Dark 44 / 61. A first attempt captured screen regions instead and measured the terminal covering the hidden windows — discarded.
  Dry run: Empty Trash ↩↩ logged only "system command empty-trash (dry run)" — no "started"/"finished" (the dry run returns before the queue).
  Cleanup: Notes closed via its close button; the snippet editor's Cancel was not found by AX and the window closed when the app relaunched (empty snippet never saved); Mac Dark as found; clipboard unchanged; app back on real data.
Task 2: Ruling: typing during the appearance checks went through a stricter guard (launcherkeys.sh: the focused element's placeholder must be the launcher's search field) because the Notes window's text area also passes dotkeys.sh's AXTextArea check — cost if wrong: none.
Task 2: complete (commits 76cdeb0..9898030, tests: make test → ✔ Test run with 377 tests in 66 suites passed after 0.597 seconds.)
Task 3: smoke test on real data (no overrides): `tema` lists Appearance Settings first; Esc. Nothing ran.
Task 3: complete (commits 9898030..9105e96, tests: make test → ✔ Test run with 377 tests in 66 suites passed after 0.592 seconds.)
Final review: Opus general-purpose reviewer (code-reviewer.md) — 0 Critical, 0 Important, 4 Minor; "Ready to merge: Yes". No fix pass needed.
Final: minor (deferred): the new "started"/"finished" lines are `.info` (not persisted) and the old `.notice` "ended: <end>" line for non-done ends was removed — failures (timeout, refused, failed) are no longer kept by `log show`; log "finished" at `.notice` when end != .done (two lines).
Final: minor (deferred, needs Pace): dropping a second Restart/Shut Down only protects while loginwindow's osascript is still running; if loginwindow replies as soon as its dialog shows (the 22:01 log kept no "ended: canceled" line from Pace's Cancel, which hints at an immediate reply), a second ↩↩ during the dialog still raises it again — same as main; Pace's 30-second check: ↩↩ Restart, ↩↩ Restart again (expect "Restart is already running."), then Cancel. If the second dialog appears, add a time-based guard.
Final: minor (deferred): Focus 3 (a failed start frees its command) and the drop path are verified by reading the code only — the app target has no unit tests and the dry run returns before the queue; the real Toggle Dark Mode runs during the Notes check were not captured in a log stream.
Final: minor (deferred): "Restart is already running." / "Shut Down is already running." may read as "the Mac is already restarting" when the dialog is on another display — e.g. "macOS's restart dialog is already open."
Final: Ruling: no global shortcut for Appearance Settings — the spec's decision — stands.
Final: Ruling: different commands may still overlap (Restart then Shut Down while a dialog is up) — the per-command queue is the tahap-18 ruling; loginwindow's handling is unknown without sending — stands.
Final: Ruling: queued Toggle Dark Mode presses are unbounded (N presses → N toggles after an Automation prompt is answered) — each press is an intended toggle and the result matches the press count — stands.
Final: Ruling: `AppleScriptEnd.alreadyRunning` is not strictly an osascript ending — it keeps one callback for the AppDelegate — stands.
Final: Ruling: "loginwindow did not answer in time." names the process — matches the permission HUD and macOS's Automation prompt — stands.
