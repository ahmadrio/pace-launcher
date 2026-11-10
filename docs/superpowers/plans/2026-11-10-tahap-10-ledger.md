# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-10.md
Spec: docs/superpowers/specs/2026-11-10-tahap-10-design.md
Pre-flight: Tasks 1–2 both edit DateQuery.swift (zones, then differences) — sequential, no signature conflict; Task 1 changes TimeZoneNames.zone's tuple (adds showsOffset), consumed only by DateQuery. Tasks 3–4 independent.
Task 1: Ruling: WET is left out of the abbreviation list although the spec listed it — the spec's own anti-goal names "wet" as an ordinary word that must not be a zone; Lisbon is still reachable by name; spec updated — cost if wrong: typing WET gives no row.
Task 1: complete (commits 3ab899a..6207ccf, tests: make test → ✔ Test run with 343 tests in 60 suites passed after 0.583 seconds.)
Task 2: UI check (test folders): "17 aug - 1 jan" → 228 days (Date); "time in est" → 03.28 New York (UTC−5); "25 - 1" → 24 (Calculator). App back on real data.
Task 2: complete (commits 6207ccf..c375954, tests: make test → ✔ Test run with 346 tests in 61 suites passed after 0.604 seconds.)
Task 3: complete (commits c375954..2941eff, tests: make test → ✔ Test run with 347 tests in 61 suites passed after 0.592 seconds.)
Task 4: Ruling: an installed app that is not an https handler (the test catcher) is labelled by its name in the picker, not "(not found)" — found during the UI check; the plan only covered missing apps — cost if wrong: none.
Task 4: UI check (test folders; URL catcher registered temporarily): "lt2 hello" with browser test.dot.t7catcher → the catcher recorded https://example.test/?q=hello (no real browser); "lt3 x" with browser com.nonexistent.browser → the default handler got dott7://fallback?q=x and the HUD said "com.nonexistent.browser not found; opened in the default browser."; the Open with picker listed Default browser, Brave Browser, Firefox Developer Edition, Google Chrome, Safari plus "com.nonexistent.browser (not found)" / "T7Catcher". Catcher unregistered and deleted; app back on real data.
Task 4: complete (commits 2941eff..0235043, tests: make test → ✔ Test run with 348 tests in 61 suites passed after 0.617 seconds.)
Task 5: smoke on real data — "17 aug - 1 jan" → 228 days; "time in pst" → 00.32 Los Angeles (UTC−8); Settings › Quicklinks › Edit Google shows Open with: Default browser (window closed, nothing saved; settings.json mtime unchanged).
Task 5: complete (commits 0235043..56951f3, tests: make test → ✔ Test run with 348 tests in 61 suites passed after 0.592 seconds.)
Final review: fresh Opus reviewer — no Critical/Important as labelled, 6 Minor; ready to merge. Re-graded by effect:
Final: fixed abbreviations that worked through Foundation on main (pkt, trt, brt, irst, bdt, akdt, adt, nst, ndt, clt) gave no row (re-graded Important: a regression of this branch); nzt added — `abbreviations that used to work still resolve` RED→GREEN, suite 351/351.
Final: fixed the fallback HUD and picker showed a raw bundle id instead of the browser's name the spec asks for (re-graded Important: spec text unmet) — `browsers are named, not shown as bundle ids` RED→GREEN, suite 351/351.
Final: Ruling: added coverage for the review focus's positive difference example, `2026-12-25 - 1`, and the zero-offset label ("London (UTC)") — the reviewer's probe showed they already work; tests passed on first run — cost if wrong: none.
Final: minor (deferred): a chosen browser whose launch fails asynchronously (stale LaunchServices record, blocked app) gives no HUD; only a log line.
Final: minor (deferred): hand-edited "browser": "" acts as a missing browser; ids differing in case duplicate a picker entry; browsers() does not drop duplicate ids.
Final: minor (deferred): city names that are words (wake, center, reunion, phoenix…) still read as zones after a time (pre-existing).
Final: Ruling: an abbreviation used as the source ("5pm est to wib" in July) follows the city's clock with no label on the source side — the spec's decision — cost if wrong: someone meaning strict EST is an hour off in summer.
Final: Ruling: year-less dates in differences use this year ("days between today and 1 jan" in November → 313) — the spec's rule — cost if wrong: someone meaning next January gets the past one.
Final: Ruling: "29 feb" in a difference gives no row in non-leap years — same this-year rule — cost if wrong: add a year to get a result.
Final: Ruling: Indonesian "9.00 ke pt" reads PT as Pacific time — rare — cost if wrong: an unexpected time row.
Final: Ruling: only a spaced hyphen separates a difference (en/em dashes and "today-17 aug" give no row) — the spec's form — cost if wrong: retype with " - ".
Final: Ruling: "days from X to Y" is not supported — not in the spec — cost if wrong: use "days between".
Final: Ruling: FSEvents firing for a folder created two or more levels below the deepest existing one was not exercised at runtime — Core resolution is tested — cost if wrong: such a folder waits for a panel open.
Final: Ruling: the chosen browser is not shown in Settings rows or launcher subtitles — not in the spec — cost if wrong: open Edit to see it.
