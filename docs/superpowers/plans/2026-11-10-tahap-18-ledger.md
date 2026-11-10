# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-18.md
Spec: docs/superpowers/specs/2026-11-10-tahap-18-design.md
Pace, 10 Nov 2026 22:03: all four tahap-17 commands worked; Automation lists "DOT Launcher"; bug: switching macOS to Light did not switch DOT's theme (Appearance: System).
Pre-flight: Task 1 produces AppleScriptEnd.timedOut, SettingsData.ownSkinToneCount, EmojiCatalog.emoji(for:); Task 2 consumes them by the same names — consistent.
Task 1: Ruling: the `.timedOut` HUD case in AppDelegate (planned for Task 2) went into Task 1 — the new enum case made its switch non-exhaustive and `swift test` builds the app target — cost if wrong: none.
Task 1: check: osacompile compiled the new Empty Trash source (with timeout of 3600 seconds … end timeout).
Task 1: complete (commits ea3aa6e..dce199a, tests: make test → ✔ Test run with 374 tests in 65 suites passed after 1.341 seconds.)
Task 2: UI check (test folders, Appearance System; the Mac's appearance switched with DOT's own Toggle Dark Mode and returned to Dark, as found):
  RED on dce199a — panel glass mean luminance (scratchpad/t12/luma, right half): Dark 29; after a live switch to Light 146 (muddy grey: light-mode text on the dark tint); after relaunching DOT in Light 252.
  GREEN — Dark 25 → live switch to Light 252 → back to Dark 25, no relaunch.
  Forced Dark (test settings appearance "dark"): Mac Dark 27, Mac Light 73 — still the dark theme (light text on dark glass; the glass shows the lighter windows behind); test settings returned to "system".
  Two real presses of a temporary ⌃⌥⌘7 Toggle Dark Mode shortcut 63 ms apart: log shows two "system command toggle-dark-mode" runs, both done (no "ended:" lines), appearance ended Dark as it began; shortcut removed afterwards.
  `tema` first listed Empty Trash (via its "tempat sampah" alias; safe behind ↩↩) — see Ruling below; after it, `tema` and `appearance` list Settings first.
  Emoji: 👍 own tone mediumDark, ⌘T → "Skin tone: Light · 👍🏾 keeps its own tone"; tones returned to none / {}.
  Document closed, clipboard unchanged, app back on real data.
Task 2: Ruling: "tema", "theme" and "appearance" added as aliases of the Settings command — with "tema" gone from Toggle Dark Mode, Empty Trash topped "tema" through its "tempat sampah" alias; Pace looking for DOT's theme now lands on Settings (General opens; Appearance is one click away) — cost if wrong: one extra click to reach Appearance.
Task 2: Ruling: the AppleScript queue is per command (not global) — a long Empty Trash must not hold up a dark-mode toggle — cost if wrong: different commands may still overlap (they touch different apps).
Task 2: complete (commits dce199a..8ca3c0d, tests: make test → ✔ Test run with 374 tests in 65 suites passed after 1.283 seconds.)
Task 3: smoke test on real data (no overrides): `tema` lists Settings first; panel glass luma 27 in Dark; Esc. Nothing ran.
Task 3: complete (commits 8ca3c0d..80cfa06, tests: make test → ✔ Test run with 374 tests in 65 suites passed after 1.312 seconds.)
Final review: Opus general-purpose reviewer (code-reviewer.md) — 0 Critical, 0 Important, 6 Minor; "Ready to merge: Yes". No fix pass needed.
Final: minor (deferred): the per-command FIFO also queues Restart / Shut Down / Empty Trash — a second ↩↩ while macOS's restart dialog is up raises the dialog again after Cancel (serialize only Toggle Dark Mode; ignore duplicates of the others).
Final: minor (deferred): a timeout from an unanswered Automation prompt says "<target> is still working on it." for every command (keep that wording for Empty Trash only).
Final: minor (deferred): the serialization evidence is indirect — "system command" is logged before queueing and the double-press check has no RED; log run start/end or unit-test a Core FIFO.
Final: minor (deferred): "theme"/"tema"/"appearance" open Settings on General, not Appearance (an Appearance command could call show(section: .appearance)).
Final: minor (deferred): Notes and the snippet editor were not screenshotted across a live switch (they use dynamic system colours and keep appearance nil, so they should follow).
Final: done (doc accuracy): HANDOFF's Emoji row mentions the ⌘T "keeps its own tone" note.
Final: check (declined item): the multi-line Empty Trash source compiles when passed as one `-e` argument with newlines, as the runner passes it (osacompile; nothing sent).
Final: Ruling: forced Dark's glass luminance rises 27 → 73 when the Mac turns Light — Liquid Glass translucency over lighter windows, pre-existing; the screenshot still shows the dark theme — stands — cost if wrong: Pace may want a more opaque forced-dark glass.
Final: Ruling: how loginwindow handles two overlapping restart requests is unknown without sending them — stands (see the deferred FIFO minor).
Final: Ruling: appearance KVO on accent-only changes — a re-apply is idempotent — stands.
Final: Ruling: ThemeController's `windows` list grows per snippet-editor open until the next apply — pre-existing, now cleaned more often — stands.
