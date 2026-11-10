# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-20.md
Spec: docs/superpowers/specs/2026-11-10-tahap-20-design.md
Pace, 10 Nov 2026 22:45: a repeat Restart while its dialog is open is ignored safely ("untuk restart sudah aman").
Probe before the plan (working tree, test folders): a password-first form showed macOS's "Passwords…" AutoFill popup on focus (RED, t20-popup-before); with `.textContentType(.oneTimeCode)` on the SecureField the popup is gone and ↩ + typed-ahead `secret` / `hello` ran on the first ↩ (markers "secret", "hello"). The change stays (uncommitted until Task 2).
Pre-flight: Task 1 produces SystemCommand.busyMessage and ScriptArgument.firstTypingIndex(in:); Task 2 consumes them — consistent.
Task 1: complete (commits 2ef4baf..1e2b04e, tests: make test → ✔ Test run with 379 tests in 66 suites passed after 0.603 seconds.)
Task 2: UI check (test folders; temporary askpw.sh "API key" password, askpick.sh dropdown + optional Note, askonly.sh dropdown only; keys via guardtype / launcherkeys.sh): password form — one window (no AutoFill popup), ↩ + `secret` then one ↩ → marker "secret"; `log show --info` for the last 3 min has no "secret". Dropdown-first — focus on "Note (optional)" holding "xy", search empty; ↩ → "red|xy" (before: "xy" stayed in the search field, tahap-15 ledger). Dropdown-only — focus stays in the search field; Esc; nothing ran. Temporary scripts and markers removed, document closed, clipboard unchanged, app back on real data.
Task 2: note: the persisted-log change is verified by reading the code (no real failure was triggered); levels are .notice for non-done ends and dropped repeats, .info for done.
Task 2: complete (commits 1e2b04e..a9d7cb8, tests: make test → ✔ Test run with 379 tests in 66 suites passed after 0.612 seconds.)
Task 3: smoke test on real data (no overrides): `calc` in the launcher; Esc. Nothing ran.
Task 3: complete (commits a9d7cb8..773ebbb, tests: make test → ✔ Test run with 379 tests in 66 suites passed after 0.610 seconds.)
Final review: Opus general-purpose reviewer (code-reviewer.md) — 0 Critical, 0 Important, 4 Minor (docs/comment accuracy); "Ready to merge: Yes". No fix pass needed.
Final: done (doc/comment accuracy): HANDOFF and the spec now state the one-time-code trade-off (no Keychain/Passwords AutoFill in script password fields; a fresh code from Messages or Mail may be offered for a few minutes and may swallow the first ↩ — untested with a real code); LauncherModel.moveTypedAhead's comment no longer says dropdown-first forms are unhandled; HANDOFF scopes Pace's 22:45 Restart check to the dropped repeat (old message) and adds the dropdown-only behaviour.
Final: minor (deferred): the fresh-verification-code case for `.oneTimeCode` is untested (optional check: mail yourself "Your verification code is 482913", open a password form with typed-ahead text, press ↩ once); a pre-filled-value alternative that keeps Keychain AutoFill is unproven.
Final: minor (deferred): `first typing field` test could add [dropdown, dropdown, password] → 2.
Final: Ruling: with Full Keyboard Access on, a dropdown-only form no longer focuses its picker — ↩ in search runs the script, which a focused popup button would not — stands — cost if wrong: one Tab to reach the picker.
Final: Ruling: "The restart dialog is already open." is wrong while osascript waits on an Automation prompt (only after make reset-tcc) or lingers after an app vetoes — rare — stands.
Final: Ruling: `.failed(message)` persisted at .notice may name a Trash item from a Finder error — fixed scripts, Pace's own Mac, same as before tahap 19 — stands.
Final: Ruling: typed-ahead password text is briefly visible in the search field (and stays if no field editor is found within 100 ms) — pre-existing since tahap 15; this branch reduces it — stands.
Final: Ruling: ⌘Z in the search field after Esc might bring back moved typed-ahead text — pre-existing, unverified — stands.
