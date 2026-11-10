# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-13.md
Spec: docs/superpowers/specs/2026-11-10-tahap-13-design.md
Pre-flight: Task 1 produces PressConfirmation.press(_:at:stillShown:), isArmed(_:at:), EmojiSkinTone.default; Task 2 consumes the first two by the same names and renames `.none` uses — consistent.
Task 1: check: with the untonedBases guard removed, `toned emoji are base plus modifier or unchanged` fails with 3 issues (👪 👯 🤼); guard restored.
Task 1: complete (commits 6ff2f6d..5c085be, tests: make test → ✔ Test run with 362 tests in 64 suites passed after 0.621 seconds.)
Task 2: UI check (test folders + DOTSystemCommandDryRun): `log out` ↩ → "Press ↩ again to log out"; after 3.6 s the footer is back to "DOT Launcher"; ↩ → the notice again, no log line; ↩ 0.3 s later → "system command log-out (dry run, focus released: true)" once. gone.sh moved out of the test Scripts folder → ⌃⌥⌘6 → red HUD "Script not found: gone.sh"; moved back → ⌃⌥⌘6 → "Gone is back" HUD and log "script shortcut: Gone Back". TextEdit document stayed empty and was closed; clipboard hash unchanged (empty, e3b0c442…); flag removed; app back on real data.
Task 2: complete (commits 5c085be..e2cb2a3, tests: make test → ✔ Test run with 362 tests in 64 suites passed after 0.618 seconds.)
Task 3: smoke test on real data (no overrides, no dry-run key): Search Emoji opened; ⌘T ×6 cycled Default → … → Dark → Default (footer "Skin tone: Default"; real settings.json rewritten during the cycle, final value "none" as before); Esc ×2, nothing pasted. Settings › Shortcuts listed 28 shortcut buttons; window closed via its close button.
Task 3: complete (commits e2cb2a3..f7f4630, tests: make test → ✔ Test run with 362 tests in 64 suites passed after 0.622 seconds.)
Final review: Opus general-purpose reviewer (code-reviewer.md) — 0 Critical, 0 Important, 3 Minor; "Ready to merge: Yes". No fix pass needed.
Final: note: reviewer asked to check real data for orphaned script shortcuts — real settings.json shortcuts are {"launcher": "cmd+space"} only, so no combo is newly taken on Pace's Mac.
Final: minor (deferred): the 3.1 s clearing Task hard-codes the 3 s window and gives up if the arm outlives one sleep (only after a backward wall-clock step); a negative elapsed time counts as armed.
Final: minor (deferred): the menu bar's "All Shortcuts" lists a missing script ("⌃⌥⌘6 gone.sh") like a working one; a "(not found)" title would say so.
Final: minor (deferred): PressConfirmationTests' new tests declare a local `t0` that shadows the suite's.
Final: Ruling: double-clicking the Log Out row is two presses (arm, confirm) — a double-click on "Log Out" is a deliberate gesture and macOS still shows its own dialog — stands — cost if wrong: the macOS log-out dialog appears and logs out by itself after ~60 s if ignored.
Final: Ruling: script-shortcut confirmation HUD lasts 2.2 s while its arm lasts 3 s (pre-existing, outside this plan) — a second press of the same global combo 2.2–3 s later runs a script the user just triggered — stands for now, candidate for the next stage — cost if wrong: a needsConfirmation script runs without its prompt visible.
Final: Ruling: missing scripts keep their combos on every Mac the settings sync to — spec decision — stands — cost if wrong: a combo is held on a Mac without the script and only shows a HUD.
Final: Ruling: RGI completeness beyond 👪 👯 🤼 not verifiable offline; the test checks shape — stands (these are the known modifier bases without base+modifier RGI forms) — cost if wrong: another rare emoji shows base + swatch in apps with their own emoji images.
Final: Ruling: duplicate combos across script keys can register twice — only via a hand-edited settings.json, the UI prevents it — stands — cost if wrong: one of two scripts answers the combo.
Final: Ruling: a missing script whose combo cannot register keeps re-applying shortcuts on every script reload — negligible cost — stands.
Final: Ruling: "Script not found" also appears for a file without a metadata header or an iCloud placeholder (pre-existing text) — stands — cost if wrong: a slightly imprecise message.
Final: Ruling: HANDOFF links the tahap-13 ledger before it is in docs — normal workflow step, done now — cost: none.
