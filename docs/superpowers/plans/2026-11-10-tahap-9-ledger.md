# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-9.md
Spec: docs/superpowers/specs/2026-11-10-tahap-9-design.md
Pre-flight:
- Task 1 → Task 2: DateQuery.Result/evaluate/display produced in Task 1, extended in Task 2 (same file) — consistent.
- Task 1/2 → Task 3: the app consumes evaluate(_:now:timeZone:) and display(_:locale:timeZone:) — consistent.
- Tasks 4–5 touch separate files.
Task 1: complete (commits d753cf9..96aff9e, tests: make test → ✔ Test run with 330 tests in 58 suites passed after 0.580 seconds.)
Task 2: complete (commits 96aff9e..e524755, tests: make test → ✔ Test run with 335 tests in 59 suites passed after 0.615 seconds.)
Task 3: UI check (test folders): first rows — "now + 3 days" → Friday, 13 November 2026 at 14.59 (Date); "days until 17 aug" → 280 days; "time in tokyo" → 16.59 Tokyo; "23.00 wib in tokyo" → 01.00 Tokyo · Wed; "now" → no date row (Center command first); "10 in in cm" → 25,4 cm (Convert). ⏎ on the countdown copied "280"; clipboard restored with a matching hash. App back on real data.
Task 3: complete (commits e524755..73d2d61, tests: make test → ✔ Test run with 335 tests in 59 suites passed after 0.593 seconds.)
Task 4: complete (commits 73d2d61..d7fca56, tests: make test → ✔ Test run with 339 tests in 59 suites passed after 0.595 seconds.)
Task 5: UI check (test folders): Scripts made a symlink to ScriptsReal; creating late.sh with the panel closed logged one reload and "Late Test registered as ⌃⌥⌘8". Folder restored, app back on real data, Pace's UserDefaults untouched.
Task 5: complete (commits d7fca56..df478c3, tests: make test → ✔ Test run with 340 tests in 59 suites passed after 0.596 seconds.)
Task 6: smoke on real data — "days until 17 aug" → 280 days, "time in tokyo" → 17.02 Tokyo (Date rows; nothing copied).
Task 6: complete (commits df478c3..9d42d40, tests: make test → ✔ Test run with 340 tests in 59 suites passed after 0.626 seconds.)
Final review: fresh Opus reviewer — no Critical/Important as labelled, 7 Minor; ready to merge. Re-graded by effect:
Final: fixed the internal marker showed in quicklink subtitles for templates with {query} in the host (re-graded Important: a regression of this branch, visible text) — `readable hosts` extended RED→GREEN, suite 340/340.
Final: Ruling: HANDOFF's WIT note (#7) corrected in the fix pass — Task 6's own deliverable — cost if wrong: none.
Final: minor (deferred): "kolkata" (macOS lists Asia/Calcutta) gives no row; add kolkata/india/bengaluru aliases.
Final: minor (deferred): 29 Feb without a year gives no row; step years until valid.
Final: minor (deferred): AEST maps to Sydney (AEDT in summer) and EST/PST/CET follow their cities' DST while the label keeps the standard name; aedt/acst/awst unknown — needs a decision on what the abbreviations mean.
Final: minor (deferred): ordinary words after a time resolve as zone abbreviations (5pm to eat → EAT, cat, art, wet…); use an allowlist.
Final: minor (deferred): a script folder missing two or more levels is not resolved, so its later creation is not matched.
Final: Ruling: `5pm in london` means "my 5pm shown in London" — the spec defines it — cost if wrong: someone expecting London's 5pm in WIB reads the wrong way round.
Final: Ruling: `today + 3 hours` is 03:00 today — the plan's test — cost if wrong: someone expecting now + 3 h.
Final: Ruling: conversions use today in the source zone, and the day marker is relative to the source zone — follows the spec — cost if wrong: a conversion near midnight shows tomorrow's moment without a marker (time of day still right).
Final: Ruling: absurd arithmetic (today - 3000 years, ±999999-year terms) shows odd dates without an era — nothing crashes — cost if wrong: nonsense for nonsense input.
Final: Ruling: split duplicate quicklink ids changed from url#index to url#index#1 — a never-saved split id loses its usage history once — cost if wrong: one reset of ranking for a hand-copied quicklink.
Final: Ruling: TimeZone.current/Locale.current may lag after the Mac changes zone — existing pattern, untestable here — cost if wrong: a stale zone until relaunch while travelling.
Final: Ruling: non-Gregorian locales display in their own calendar while arithmetic is Gregorian — not Pace's locale — cost if wrong: confusing dates for those locales.
Final: Ruling: the first row disappears while a unit is half typed (now + 3 d → da) — same as the calculator — cost if wrong: brief flicker.
