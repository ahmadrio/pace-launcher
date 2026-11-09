# SDD ledger — plan: docs/superpowers/plans/2026-11-09-tahap-2.md
Spec: docs/superpowers/specs/2026-11-09-tahap-2-design.md
Setup: Ruling: work on in-place branch `tahap-2` (from main @ 778972c) instead of a separate worktree — single-user repo, no remote; build/install/TCC signing pipeline already tuned for this checkout — cost if wrong: none, merge or delete branch.

## Pre-flight (shared interfaces)
| Producer → Consumer | Produces / consumes | Finding |
|---|---|---|
| T2 → T7,T8,T10,T14 | ModeHandler, SecondaryAction, KeyShortcut.delete, PressConfirmation | consistent |
| T3 → T7,T8,T10 | TextPaster.copy(_:), TextPaster.paste(_:monitor:) | consistent |
| T5 → T7,T8 | TranslationDirection.auto(...), LanguageDetector.dominantLanguage(of:) | T8 needs a direction lang→en for bridge; TranslationDirection has no public init → Ruling below |
| T6 → T8 | ChatLanguageRoute.route, MarkdownSegments.split/join | consistent |
| T7 → T8 | Translator.availability(_:), Translator.translate(_:_:) | consistent |
| T9 → T10,T11 | Snippet, SnippetStore, SnippetExpander.expand | consistent |
| T10 → T14 | AppPaths.snippetsDirectory / notesDirectory | consistent |
| T12,T13 → T14 | NoteStore, NoteTitle, MarkdownHighlighter.spans | consistent |
| T1 → T14 | Window menu Close ⌘W | consistent |
Pre-flight: Ruling: add `public init(source: String, target: String)` to TranslationDirection in T5 — T8 bridge must build an explicit lang→en direction — cost if wrong: one extra initializer.
Task 1: complete (commits 778972c..f3e5b33, tests: swift test → ✔ Test run with 74 tests in 15 suites passed after 0.523 seconds.)
Task 2: Ruling: intercept shortcuts in LauncherPanel.sendEvent (keyDown with ⌘ or ⌃) instead of performKeyEquivalent — Control-only shortcuts like ⌃X are not reliably offered as key equivalents; menu equivalents (⌘C/⌘V) still go to the main menu first — cost if wrong: none, same observable behavior.
Task 2: Ruling: add LauncherResult.Action.stay (run without closing the panel) — ⌘L swap, ⌘N new chat, ⌃X delete must keep the panel open — cost if wrong: one enum case.
Task 2: Ruling: ModeHandler also gets `results` (async list provider; clipboard moved onto it), `submitTitle`, and `entered` — list modes (.snippets/.notes) need a row source and the footer needs a ⏎ label; `entered` hosts AI prewarm — cost if wrong: three optional fields.
Task 2: complete (commits f3e5b33..21e1aa5, tests: swift test → ✔ Test run with 78 tests in 16 suites passed after 0.532 seconds.)
Task 3: Ruling: TextPaster.paste skips the restore when the pasteboard changed again during the 500 ms wait — the user may copy something new in that window; restoring would clobber it — cost if wrong: in that rare case the old clipboard is not restored.
Task 3: note: verification used fresh uniquely named TextEdit docs; an earlier probe doc had been autosaved into TextEdit's container (~/Library/Containers/com.apple.TextEdit/Data/DOT paste probe) and became "Locked", which made ⌘V offer to duplicate it — test artifact, not a product bug.
Task 3: complete (commits 21e1aa5..12db258, tests: swift test → ✔ Test run with 78 tests in 16 suites passed after 0.535 seconds.)
Task 4: Ruling: LauncherSearch takes `commands: () -> [LauncherCommand]` and rebuilds on every panel show — command subtitles (icon state, Accessibility granted) must be current; rebuild of ~120 candidates is ~1 ms — cost if wrong: negligible CPU per open.
Task 4: Ruling: verification counts items of `menu bar 2` — Task 1's main menu now occupies menu bar 1 (Apple, DOT Launcher, Edit, Window), so the plan's `menu bar 1` check always read 4 — cost if wrong: none (test harness only).
Task 4: Ruling: PanelController.hide() calls NSApp.hide(nil) when DOT is active — reopening via Finder/`open` can activate DOT; global constraint says the previous app must stay frontmost — cost if wrong: none observed (hotkey path never activates DOT).
Task 4: complete (commits 12db258..1fff6ce, tests: swift test → ✔ Test run with 78 tests in 16 suites passed after 0.527 seconds.)
Task 5: complete (commits 1fff6ce..4209910, tests: swift test → ✔ Test run with 84 tests in 17 suites passed after 0.528 seconds.)
Task 6: complete (commits 4209910..0d95e0e, tests: swift test → ✔ Test run with 93 tests in 19 suites passed after 0.527 seconds.)
Task 7: Ruling: `@preconcurrency import Translation` — the SDK's async methods are not nonisolated(nonsending) and its types are not Sendable, so Swift 6 rejected calling them on main-actor state; all calls start on the main actor serially — cost if wrong: a data race the compiler can no longer flag (Translation calls only).
Task 7: Ruling: custom mode views are registered as `LauncherModel.customContent[mode]` (AnyView factories) — keeps PanelController/LauncherView generic for translate and AI — cost if wrong: AnyView type erasure in two views.
Task 7: note: on this Mac every tested pair (ja, uk, th, pl, tr, vi, ko, de, ar, hi → id) reports `installed`, so the `.notInstalled` message path could not be exercised live; the `.unsupported` path was (Latin detected as Catalan → clear message, no hang).
Task 7: complete (commits 0d95e0e..7dc7dbe, tests: swift test → ✔ Test run with 93 tests in 19 suites passed after 0.552 seconds.)
Task 8: Ruling: map errors from `LanguageModelError` (macOS 27: contextSizeExceeded, guardrailViolation, refusal) instead of the plan's `LanguageModelSession.GenerationError` — the SDK deprecates GenerationError in 27.0 — cost if wrong: a context-overflow could show the generic message instead of "start a new chat".
Task 8: Ruling: ChatMessage gains `isBridged` (drives the dimmed "English draft" look) — the plan's Phase alone can't tell a bridged stream from a direct one — cost if wrong: one field.
Task 8: Ruling: ⌘⇧C "Copy Answer" keeps the panel open and shows the footer notice "Answer copied"; footer notices are neutral (info icon) instead of orange — copy is a success message, not a warning — cost if wrong: cosmetic.
Task 8: Ruling: stopping (Esc) a bridged answer keeps the partial English text untranslated — translating a truncated answer would cost more time for little value — cost if wrong: user sees English after stopping.
Task 8: Ruling: ChatView uses defaultScrollAnchor(.bottom) + scroll on appear — the view is rebuilt on each mode entry, often after a send, so onChange never fired and it opened at the top — cost if wrong: none.
Task 8: complete (commits 7dc7dbe..7da6a37, tests: swift test → ✔ Test run with 93 tests in 19 suites passed after 0.530 seconds.)
Task 9: Ruling: SnippetExpander is a single left-to-right pass instead of per-placeholder replacement — sequential replacement (dictionary order) expanded "{date}" found inside clipboard text, nondeterministically; added tests `clipboard text is inserted literally` and `an unclosed brace is left as written` (both seen RED first) — cost if wrong: none.
Task 9: Ruling: Snippet gets a public memberwise-style init with defaults (id, keyword, dates) — public structs get no public synthesized init — cost if wrong: none.
Task 9: complete (commits 7da6a37..21671ab, tests: swift test → ✔ Test run with 103 tests in 21 suites passed after 0.538 seconds.)
Task 10: Ruling: LauncherSearch receives snippets through `snippets: () -> [Snippet]` and `snippetRow: (Snippet) -> LauncherResult` closures set by AppDelegate — keeps row building (paste/edit/delete wiring) in one place for root and `.snippets` mode — cost if wrong: none.
Task 10: complete (commits 21671ab..2b44f33, tests: swift test → ✔ Test run with 103 tests in 21 suites passed after 0.550 seconds.)
Task 11: Ruling: editor state lives in an @Observable `SnippetDraft` (keeps id and createdAt when editing; trims name/keyword; empty keyword → nil) — the plan named the controller only — cost if wrong: none.
Task 11: complete (commits 2b44f33..752b989, tests: swift test → ✔ Test run with 103 tests in 21 suites passed after 0.535 seconds.)
Task 12: complete (commits 752b989..cc326fa, tests: swift test → ✔ Test run with 111 tests in 23 suites passed after 0.539 seconds.)
Task 13: complete (commits cc326fa..666b037, tests: swift test → ✔ Test run with 121 tests in 24 suites passed after 0.547 seconds.)
Task 14: Ruling: no `@State` anywhere — on the macOS 27 SDK `@State` is a SwiftUI macro whose plugin (SwiftUIMacros) the Command Line Tools do not ship; view-local state lives in @Observable models instead (NotesModel.switcherQuery) — cost if wrong: none; add to HANDOFF pitfalls.
Task 14: Ruling: notes are not ranked in root search (only via Search Notes mode) and LauncherSearch was left untouched — the spec lists Open/Create/Search Notes commands only — cost if wrong: one more Item case later.
Task 14: Ruling: the text view is focused from its onCreate callback as well as on present — on first open SwiftUI builds the NSTextView after makeKeyAndOrderFront, so keystrokes had no first responder — cost if wrong: none.
Task 14: Ruling: the notes header ignores the top safe area so it sits in the transparent title bar beside the window buttons — otherwise an empty title-bar row appeared above it — cost if wrong: cosmetic.
Task 14: Ruling: NotesModel flushes on app termination too (applicationWillTerminate) — the 0.5 s debounce could otherwise lose the last keystrokes on quit — cost if wrong: none.
Task 14: complete (commits 666b037..839bcf4, tests: swift test → ✔ Test run with 121 tests in 24 suites passed after 0.546 seconds.)
Task 15: Ruling: snippets are re-read from disk on every panel open (panelController.onShow → snippets.reload) — the smoke run showed a snippet file added while the app ran was invisible until relaunch (";smk" fell through to Ask AI); files are meant to be editable/synced externally — cost if wrong: a few file reads per open.
Task 15: complete (commits 839bcf4..2bc1d91, tests: swift test → ✔ Test run with 121 tests in 24 suites passed after 0.525 seconds.)
Final: fixed notes trash lost later typing (and, found while fixing, revived the trashed text) — UI repro f1-check.sh RED (saved 0; then revived 1) → GREEN (saved 1, revived 0), suite 121/121
Final: fixed key auto-repeat confirming ⌃X deletes — UI repro f2-check.sh (CGEvent autorepeat) RED (deleted) → GREEN (survived); two real presses still delete; suite 121/121
Final: fixed AI bridge told users to download unsupported languages, and ms→id applied only in the translator — LanguageTests `Malay is reported as Indonesian` RED→GREEN; UI repro f3-check (Latin→Catalan) RED ("Download Catalan…") → GREEN ("does not support Catalan. Ask in English."), suite 122/122
Final: fixed Translate Copy/Paste acting on a stale or empty translation (status now becomes .translating as soon as the text changes; ⏎ and ⌘↩ require a finished translation) — UI repro f4-check (b) RED (copied "good morning") → GREEN (clipboard unchanged); (a) empty ⌘↩ could not be reproduced in TextEdit (it ignores empty pastes), covered by the same guard; normal copy still works; suite 122/122
Final: re-grade: #4 (empty ⌘↩ paste) and #7 (stale output copied) raised from Minor to Important by effect (silent wrong/empty output into the user's document); fixed together above.
Final: minor (deferred): Notes — scheduleSave clears deleteArmed but not the confirmation, and armed labels (notes trash, snippet editor Delete) never expire visually after 3 s.
Final: minor (deferred): ⌘W in the borderless launcher panel beeps (Window ▸ Close → performClose on a window without a close button).
Final: minor (deferred): Ask AI / ⏎ while an answer is still generating drops the new question silently.
Final: minor (deferred): cancel() keeps isGenerating true until the stream unwinds; a fast re-send can surface LanguageModelSession concurrentRequests as a raw message.
Final: minor (deferred): scale costs — full restyle per keystroke, notes search reads every body per keystroke, NoteStore.list() on every flush (fine at tens of notes).
Final: minor (deferred): SnippetStore.delete derives the path from the JSON id; a hand-copied file whose id differs from its filename cannot be deleted.
Final: Ruling: {date}/{time} use fixed yyyy-MM-dd / HH:mm — spec leaves the format to the builder; predictable output for pasting — cost if wrong: a locale-formatted date is one setting later.
Final: Ruling: snippets delete permanently while notes go to the Trash — spec names the Trash for notes only; with auto-repeat fixed, deletion needs two real presses — cost if wrong: an accidental double ⌃X loses a snippet (tracked as a recommendation: trashItem for parity).
Final: Ruling: footer shows at most two secondary hints — plan says up to two; ⌘↩/⌘⇧O in AI stay discoverable via HANDOFF — cost if wrong: discoverability.
Final: Ruling: no timeout around translate()/streamResponse — every error path returns a message; a framework stall is outside the app's control and was not observed — cost if wrong: a rare stuck "Thinking…" until Esc.
Final: Ruling: notes are not ranked in root search — spec lists only Open/Create/Search Notes — cost if wrong: one more Item case later.
Final: Ruling: no in-app hint after Hide Menu Bar Icon — launcher commands and reopen-from-Finder cover it; HANDOFF documents it — cost if wrong: a confused moment.
Final: Ruling: UI strings in English — stage-1 convention; spec leaves message text to the builder — cost if wrong: copy edits.
Final: Ruling: skip the clipboard restore when it changed during the 500 ms wait — protects a newer user copy (reviewer agrees) — cost if wrong: rare unrestored clipboard.
Final: Ruling: Esc on a bridged answer leaves the partial English untranslated — reviewer agrees — cost if wrong: English after stopping.
Final: Ruling: 500 ms restore delay kept — spec value; no failure observed in TextEdit — cost if wrong: a slow app could paste the restored clipboard; raise the delay then.
Final: Ruling: "English draft" label instead of "English" — clearer that it will be replaced — cost if wrong: wording.
Final: Ruling: brief flash of the status item at launch before it hides — cosmetic; NSStatusItem is created visible — cost if wrong: a sub-second flicker.
