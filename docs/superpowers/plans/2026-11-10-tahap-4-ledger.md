# SDD ledger — plan: docs/superpowers/plans/2026-11-10-tahap-4.md
Branch: tahap-4 from main @ ac995b9. Spec: docs/superpowers/specs/2026-11-10-tahap-4-design.md (Pace opted out of questions; spec decisions are Claude's calls).
Pre-flight: T1→T2 ChatStore/SavedChatMessage.exchange/ChatSummary — consistent.
Pre-flight: T3→T4 ClipImage.make, ClipboardFilter.isImageCopy/shouldIgnore(hasImage:), ClipboardStore.imageURL/thumbnailURL — consistent.
Pre-flight: T3→T5 ClipStats.summary, imageURL; T5 uses existing setPinned/delete — consistent.
Pre-flight: T6→T7 Shortcuts.resolve/validate/followsOtherAppHabit/saved, ShortcutID.title as HotKeyCenter name — consistent.
Task 1: complete (commits a03c486..5bc38a2, tests: make test → ✔ Test run with 195 tests in 39 suites passed after 0.545 seconds.)
Task 2: Ruling: "History ⌘Y" is the last AI-mode action, not right after New Chat — the footer shows only the first two actions, so Copy/Paste Answer stay visible; the empty AI view says "Press ⌘Y for saved chats" — cost if wrong: History is not in the footer once an answer exists.
Task 2: Ruling: deleting the open chat (or Delete All) resets AI mode — otherwise the next exchange would re-create the deleted chat under the same id — cost if wrong: the conversation on screen clears after deleting it from history.
Task 2: Ruling: history rows open with `.stay { Task { await open; reset(to: .ai) } }` and deletes refresh after the await — the store is an actor, so `.stay`'s immediate refresh would list stale rows — cost if wrong: none.
Task 2: UI check (test folder t4-data): answer saved (2 rows), ⌘Y list "2 messages · 22 sec ago", relaunch → open from history → follow-up quoted the earlier question (context resumed), ⌃X once → "Press ⌃X again to delete", twice → 0 chats/0 messages, AI mode empty with ⌘Y hint; Indonesian question saved with English originals ("Name one planet in our solar system." / "Earth").
Task 2: complete (commits 5bc38a2..1595630, tests: make test → ✔ Test run with 195 tests in 39 suites passed after 0.567 seconds.)
Task 3: Ruling: added the .image case to ClipboardController's kind switch in Task 3 (planned for Task 4) — swift test builds the app target, so the exhaustive switch had to compile — cost if wrong: none.
Task 3: complete (commits 1595630..c6725d3, tests: make test → ✔ Test run with 211 tests in 41 suites passed after 0.576 seconds.)
Task 4: Ruling: an image clip whose file is missing gets a `.stay` row action that shows "Image unavailable" in the footer (row subtitle says so too), instead of the plan's paste-then-report — `.run` closes the panel first, so a notice there would never be seen — cost if wrong: none.
Task 4: UI check (test folder): pbtool put a 640×400 PNG → row kind image, "Image 640 × 400", <hash>.png + -thumb.png written; copied again → use_count 2, one row; list row shows the thumbnail; ⏎ pasted the image into a new TextEdit doc (screenshot; the AppleScript attachment count failed, doc "Untitled 10.rtfd" closed unsaved); png moved away → subtitle + footer "Image unavailable", pasteboard hash unchanged; Pace's clipboard restored (hash fc0b17… before and after).
Task 4: complete (commits c6725d3..8c52594, tests: make test → ✔ Test run with 211 tests in 41 suites passed after 0.577 seconds.)
Task 5: Ruling: the list is a fixed 320 pt (≈45% of the 720 pt panel) instead of a relative width — the panel size is fixed, so a constant is simpler — cost if wrong: none until the panel becomes resizable.
Task 5: Ruling: row icons now use scaledToFit — image thumbnails are not square and were stretched to 28×28; app icons are square so unchanged — cost if wrong: none.
Task 5: Ruling: Pin/Delete run through ClipboardController.change { … } then onChange → model.refresh(), not `.stay`'s immediate refresh — the store is an actor — cost if wrong: none.
Task 5: UI check (test folder): image preview full size; text preview with "Finder · Copied 16 seconds ago · Used once · 36 characters · 3 lines"; footer Paste/Pin ⌘P/Delete ⌃X; ⌘P → "beta" first with "Pinned" (pinned=1 in DB); ⌃X once → "Press ⌃X again to delete", twice → image row gone and both its files removed; Pace's clipboard restored (hash fc0b17… before/after).
Task 5: complete (commits 8c52594..9322691, tests: make test → ✔ Test run with 211 tests in 41 suites passed after 0.825 seconds.)
Task 6: complete (commits 9322691..f5ebdea, tests: make test → ✔ Test run with 226 tests in 42 suites passed after 0.578 seconds.)
Task 7: Ruling: HotKeyCenter is now @Observable (internals @ObservationIgnored) — Settings rows read hotKeys.status and must update when Maccy/Rectangle start or quit — cost if wrong: none.
Task 7: Ruling: Reset validates the default like a recorded combo — a default can clash with a custom combo picked for another shortcut — cost if wrong: Reset shows an error instead of creating a duplicate.
Task 7: Ruling: GatedHotKey kept only as a namespace for Blocker (the status menu uses it); the per-shortcut actions live in AppDelegate.shortcutActions and applyShortcuts replaces applyGatedHotKeys — cost if wrong: none.
Task 7: Ruling: status menu "Open DOT Launcher" shows the registered launcher combo (hotKeys.combo(of:)) instead of the removed static launcherHotKey — cost if wrong: none.
Task 7: Observation (pre-existing, tahap 3): Settings opened from the launcher does not make DOT the active app (menu bar stays on Finder); AX clicks do not activate either, so the UI test activates DOT via AppleScript before recording. A real mouse click activates the window — cost if wrong: the first click on a recorder button may only focus the window.
Task 7: UI check (test folder): section lists 14 rows; Maccy/Rectangle running → defaults show "Off while … runs"; recording hides statuses (paused); ⌃⌥⌘L recorded → settings.json "launcher": "ctrl+opt+cmd+l", Reset button shown; over Finder ⌥Space no longer reached DOT (Finder opened Quick Look on the selected "E-Sign" folder — closed with Esc, nothing changed) and ⌃⌥⌘L opened the panel; ⌃⌥⌘L for Almost Maximize → "Already used by Open DOT Launcher."; ⌫ on launcher → "Open DOT Launcher needs a shortcut."; Reset → key removed, ⌥Space opens the panel again. ⌃⌥← could not be used for the conflict check because Rectangle owns it globally.
Task 7: complete (commits f5ebdea..c01b4cf, tests: make test → ✔ Test run with 226 tests in 42 suites passed after 0.594 seconds.)
Task 8: smoke on real data (no override): AI Chat History shows 'No saved chats yet', Clipboard History shows the preview, ⌥Space works, real settings.json byte-identical to the earlier backup, iCloud DOT Launcher folder absent.
Task 8: complete (commits c01b4cf..b5cbd48, tests: make test → ✔ Test run with 226 tests in 42 suites passed after 0.576 seconds.)
Final review: fresh reviewer (Opus) on ac995b9..b5cbd48 — 0 Critical, 3 Important, 15 Minor, "With fixes". Re-graded by effect: all 3 Important stand (anti-goals: DOT unreachable, panel stalls); no Minor raised.
Final: fixed recorder left DOT's hotkeys paused / swallowed keys from other windows — UI reproducer (start recording, switch to Finder → "Off while" statuses stayed hidden = still paused) RED→GREEN (statuses back, 12) via windowDidResignKey → stop() and a monitor that only takes keys from the Settings window; regression: recording ⌃⌥⌘L in Settings still saves, Reset clears. Suite 228/228.
Final: fixed recording that starts while Settings never gets key focus stayed pending forever — UI reproducer (open Settings from launcher, AX-click recorder: Esc never arrived, statuses hidden after 5 s) RED→GREEN (statuses back 1.8 s after start) via a 1 s "not key → cancel" check with an attempt counter. Suite 228/228.
Final: fixed text preview laid out whole multi-MB clips — ClipStats.preview(of:limit:) `a long text preview shows only its beginning` RED→GREEN (20,000-character prefix + "Showing the beginning…" note; summary cached per clip hash); UI: 3.18 MB clip opens in ~0.5 s with the preview. Suite 228/228.
Final: fixed image preview decoded full-size bitmaps on main — ClipImage.preview(at:maxPixelSize:) `the preview image is downsampled from the file` RED→GREEN (CGImageSource thumbnail, ShouldCacheImmediately, 1600 px, decoded in a @concurrent function); UI: 6000×4000 clip previews normally. Suite 228/228.
Final: fixed HANDOFF docs (tahap-3 links misplaced under tahap 4; Maccy/Rectangle line now says defaults only; recorder behaviour) — documentation only, no test.
Final: minor (deferred): AIChatController generation lifecycle — `send` clears `generation` when an older task ends, and `respond` reads `self.session` after the translation await (a cancelled bridged task can post to the next chat's session).
Final: minor (deferred): opening another chat or ⌘N mid-answer drops the in-flight exchange; an answer finishing during `delete` of the open chat can re-create it.
Final: minor (deferred): pressing only modifiers while recording shows no message (keyDown never fires; a .flagsChanged monitor would cover it).
Final: minor (deferred): no guard against recording standard app shortcuts (⌘C/⌘V/⌘W/⌘Q/⌘S) as global hotkeys.
Final: minor (deferred): applyShortcuts registers in a fixed order — a combo swap arriving via settings.json (sync/hand edit) can leave one id unregistered until the next apply.
Final: minor (deferred): Paster builds an uncompressed TIFF on main before ⌘V (≈60 MB for a 5K image).
Final: minor (deferred): PasteboardMonitor reads the whole image flavour on main before the 20 MB check.
Final: minor (deferred): no decoded-pixel limit in ClipImage.make (a small PNG can decode to gigapixels).
Final: minor (deferred): orphaned image files (written before a failed insert, a crash, or rows dropped by a backup restore) are never cleaned up.
Final: minor (deferred): ClipboardController.thumbnails (and textSummaries) caches grow without bound.
Final: minor (deferred): ⌘P captures a stale `item.pinned`; a second ⌘P before the refresh pins again.
Final: minor (deferred): deleted chats/clips stay in SQLite free pages/WAL (no PRAGMA secure_delete).
Final: minor (deferred): AI Chats lists at most 100 chats; older ones only via search.
Final: minor (deferred): Esc in AI Chats goes to root, not back to the open chat.
Final: minor (deferred): ClipboardImageStoreTests never removes its temp folders.
Final: Ruling: non-ANSI layouts show wrong key names in Settings › Shortcuts — the key table is ANSI by design and non-QWERTY is a listed limitation since tahap 1 — cost if wrong: AZERTY users see mismatched labels.
Final: Ruling: JPEG/HEIC/PDF-only copies are not image clips — macOS image copies carry TIFF/PNG; the spec names those — cost if wrong: a rare image copy is not recorded.
Final: Ruling: conflicts with apps using event taps are not detected — already a HANDOFF limitation; macOS gives no API — cost if wrong: a recorded combo silently does nothing.
Final: Ruling: Clipboard Images/ size is unbounded — spec non-goal, like the unlimited text history — cost if wrong: disk use grows with many large images.
Final: Ruling: chat search ignores the English `original` — the user searches what they saw — cost if wrong: an English term from a bridged answer is not found.
Final: Ruling: chat LIKE search is case-insensitive for ASCII only — same as ClipboardStore's short-query path — cost if wrong: "É"/"é" differ in chat search.
Final: Ruling: Settings opened from the launcher does not activate DOT — pre-existing (tahap 3); the recorder now activates DOT itself and cancels if it cannot — cost if wrong: the first click may only focus the window.
Final: Ruling: a malformed `shortcuts` value resets all settings — the corrupt-file behaviour deferred in tahap 3 — cost if wrong: a bad hand edit resets settings.json.
Final: Ruling: the full PNG ignores EXIF orientation while the thumbnail applies it — pasteboard images rarely carry an orientation tag — cost if wrong: a rotated paste for such images.
Final: Ruling: transcript fidelity for tools/structured output — the app uses neither — cost if wrong: none.
