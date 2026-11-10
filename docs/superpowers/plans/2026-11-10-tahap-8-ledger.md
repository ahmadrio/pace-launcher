# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-8.md
Spec: docs/superpowers/specs/2026-11-10-tahap-8-design.md
Pre-flight:
- Task 1 → Task 2: Emoji/EmojiCatalog.search(_:usage:limit:) produced and consumed with the same signature — consistent.
- Tasks 3–5 share nothing with each other or with 1–2 beyond existing types.
Task 1: complete (commits d8071cd..a1cef5a, tests: make test → ✔ Test run with 318 tests in 56 suites passed after 0.606 seconds.)
Task 2: Ruling: the catalog lists faces first (U+1F600–1F64F, then 1F900–1FAFF, 1F300–1F5FF, 1F680–1F8FF, 1F000–1F2FF, 2000–2BFF) instead of plain Unicode order — plain order opened the picker on ™ and arrows; spec text updated — cost if wrong: the empty list order differs from Unicode charts.
Task 2: UI check (test folders): "Search Emoji" → `cinta` → first row ❤️ Red heart; ⏎ pasted "❤️" into a new TextEdit document; clipboard hash unchanged (e3b0c442… = empty clipboard before and after), test clipboard.sqlite still 2 clips; reopening with an empty query lists ❤️ first, then Grinning face. Document closed, app back on real data.
Task 2: complete (commits a1cef5a..7f68708, tests: make test → ✔ Test run with 318 tests in 56 suites passed after 0.613 seconds.)
Task 3: UI check (test folders): a rich-text clip "plain BOLDWORD" (bold word) pasted with ⌘⇧↩ into a new TextEdit document came in as one Helvetica run (no bold); clip count stayed 3 and its use_count went 1 → 2; a normal ⏎ paste afterwards brought HelveticaNeue-Bold, as a comparison. Pace's clipboard restored (hash e3b0c442…, empty before and after). App back on real data.
Task 3: complete (commits 7f68708..9d008d6, tests: make test → ✔ Test run with 319 tests in 57 suites passed after 0.614 seconds.)
Task 4: Ruling: the plan's `host() == "xn--bcher-kva.de"` check uses the wrong API — URL.host() returns the percent-encoded original (b%C3%BCcher.de) while the URL handed to NSWorkspace is https://xn--bcher-kva.de/…; the test asserts absoluteString instead — cost if wrong: none.
Task 4: complete (commits 9d008d6..7f0e0ae, tests: make test → ✔ Test run with 322 tests in 57 suites passed after 0.631 seconds.)
Task 5: UI check (test folders, debug log): with Scripts moved away, writing Notes/t8-note.md logged no "script folders changed"; moving Scripts back logged one and registered all seven script shortcuts; writing Scripts/.git/x logged no new reload. App back on real data.
Task 5: complete (commits 7f0e0ae..7f29d6c, tests: make test → ✔ Test run with 324 tests in 57 suites passed after 0.608 seconds.)
Task 6: smoke on real data — Search Emoji + cinta → ❤️ Red heart first (Esc, nothing pasted); Clipboard History footer shows "Paste as Plain Text ⇧⌘↩" (not pressed).
Task 6: complete (commits 7f29d6c..bb5ca1d, tests: make test → ✔ Test run with 324 tests in 57 suites passed after 0.589 seconds.)
Final review: fresh Opus reviewer — 1 Important, 10 Minor; ready to merge with fixes. Re-graded by effect:
Final: fixed quicklink text encoded twice when the template needs normalizing ("|", non-ASCII) — `typed text is encoded once even when the template needs fixing` RED→GREEN, suite 325/325.
Final: fixed missing extra folders were watched through their parent (could be all of ~, per-file events on the main thread; re-graded Important: beyond the spec, battery cost) — `missing folders are watched directly, never their parents` RED (compile) → GREEN, suite 325/325. UI (test folders): with Scripts moved away, a Notes write → 0 reloads; Scripts back → 1 reload and 7 shortcuts registered; a write inside Scripts → reload.
Final: Ruling: the frecency test now compares 😴's rank for "sl" with and without usage (mutation check: zeroing frecency makes it fail); the plan's `face`/limit-30 version fails because usage lifts 😴 only from 103 to 34, and the first version ("sleeping face") proved nothing — cost if wrong: none.
Final: Ruling: emoji Copy stays ⌘C — UI check: typing `cinta` then ⌘C put ❤️ on the clipboard and closed the panel; only with the query text selected does the Edit menu copy that selection, as any text field does — cost if wrong: someone selecting the query and pressing ⌘C gets the query, not the emoji.
Final: Ruling: HANDOFF errors (#10) fixed in the fix pass — Task 6's own deliverable — cost if wrong: none.
Final: minor (deferred): script folders reached through a symlink, /tmp or /var get FSEvents real paths that isRelevant never matches (resolve with realpath).
Final: minor (deferred): flags without a glyph (🇪🇿 Eurozone, 🇶🇴 Outlying Oceania) show as letter pairs.
Final: minor (deferred): seven emoji are missing (‼️ ⁉️ ℹ️ by category; 〰️ 〽️ ㊗️ ㊙️ outside the scanned ranges).
Final: minor (deferred): popular words missing — pray/doa → 🙏, 100 → 💯, tada → 🎉, poop → 💩.
Final: minor (deferred): an IDN quicklink row shows a percent-encoded host (b%C3%BCcher.de).
Final: minor (deferred): a hand-written non-UUID quicklink id ("wiki") still makes the entry skipped and dropped on the next save.
Final: minor (deferred): `try? usage?.recordUse` in the emoji actions swallows errors that root search logs; a split quicklink id is not re-checked against ids already seen.
Final: Ruling: CLDR-wide Indonesian keywords (kucing, anjing, rumah) are not covered — the spec's non-goal — cost if wrong: those words find nothing.
Final: Ruling: physically held ⌘⇧ during the 80 ms before the synthetic ⌘V — KeyboardPaste sets the command mask explicitly — stands — cost if wrong: a rare ⇧⌘V instead of ⌘V.
Final: Ruling: without Accessibility, emoji ⏎ falls back to a permanent copy that lands in history — the documented TextPaster behaviour shared with snippets — cost if wrong: an emoji appears in clipboard history.
Final: Ruling: emoji search cost (≈1–4 ms per key in release, up to ≈45 ms in the debug build `make run` makes; ≈50 ms first open) — acceptable — cost if wrong: a slight lag in the debug build.
Final: Ruling: a short window between a reload-triggered re-watch and the restarted stream can miss an event — a panel open reloads anyway — cost if wrong: a script appearing in that window waits for the next panel open.
Final: Ruling: closing Settings discards an unsaved new quicklink — the spec's intent — cost if wrong: retyping a half-filled form.
Final: Ruling: derivedID is labelled version 5 but uses SHA-256 (RFC 9562 would say v8) — cosmetic — cost if wrong: none.
Final: Ruling: `javascript:` and host-less schemes stay accepted — tahap-7 ruling — cost if wrong: a saved quicklink can launch any registered scheme.
