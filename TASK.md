# TASK: Reverse-engineering analysis + foundation

Rules, commands and constraints are in CLAUDE.md. Follow them throughout.

**Status (2026-10-31):** Phase 3 is in progress, in speed mode (CLAUDE.md). Branches 1, `feat/now-playing-scripting`, 2, `feat/now-playing-media`, 3, `feat/compact-slot`, 4, `feat/hotkey`, and 5, `feat/notes`, are merged to main and pushed to `origin`. Branch 6, `feat/file-tray`, is in progress. Next: clipboard, settings, polish, release. See "Phase 3" below.

## Goal
Run a reverse-engineering analysis (REA) of Canopy and Atoll, turn it into a feature matrix and architecture plan for DropNotch, then scaffold the foundation. DropNotch must be original code that Shash owns.

## Phase 1: Analysis (done, 2026-10-24)
Canopy's public pages and Atoll's features were analysed, and the decisions D1–D10 were approved by Shash. Outputs: docs/FEATURE_MATRIX.md, docs/ARCHITECTURE.md, docs/RISKS.md, docs/DECISIONS.md and docs/research/.

## Phase 2: Foundation (done, 2026-10-25; plan approved 2026-10-24)

Decision numbers (D1–D14) refer to docs/DECISIONS.md. Start with the `planner` agent and send its plan to Shash. Steps a and b are verification and project setup; step a ends with a report to Shash, and no module code is built until Shash has read it.

Plan for c–j approved by Shash, 2026-10-24: branches `feat/menu-bar` (c), `feat/notch-panel` (d), `feat/hover-state` (e) and `feat/module-registry` (f), merged in that order; the g tests go in the branch whose logic they test. **After `feat/hover-state` merges, stop** and hand Shash the hover device checks from step i. `feat/module-registry` waits for Shash's report.

**Status (2026-10-25):** c, d and e are on main. The d–e checks passed on a notched Mac on 2026-10-25, after the fixes on `fix/hover-glitch`: the D16 correction, the D18 retune, the D19 canvas and D20. The notch opens centred in about 0.2–0.3 s, every deliberate hover opened it, sweeps didn't, and resting at the top edge kept it open. **Phase 2 is done.** Branch 4, `feat/module-registry` (step f; D21), passed its step j reviews (code-reviewer, test-writer, accessibility-auditor, performance-optimizer, docs-writer) and its device check on a notched Mac (6 centred opens, placeholder centred, no spill on close), and is on main. **Next: Phase 3, in progress (see "Phase 3" below).** Carried into Phase 3's accessibility checks, not yet tested: Reduce Motion (no flash or clipped frame; toggling mid-session), the Accessibility Inspector, and what VoiceOver announces for the panel. Two D20 device checks are still open; they are listed in step i.

a. **Step 0: verify before building.** Done 2026-10-24 (preview-flag run partial); report in docs/research/clipboard-probe-2026-10-24.md, reviewed by Shash; decisions D7a and D7b.
   - **Clipboard warning probe (D7).** Build a throwaway probe in a scratch folder outside DropNotch/. It is not committed. It reads `NSPasteboard.general` in the background when `changeCount` changes. Record: whether macOS shows a privacy alert or prompt on the current macOS version; what triggers it; whether reading only `changeCount` and `types` avoids it. Report the result to Shash before the Clipboard module is built.
   - **Apple API claims.** Check every [I]-tagged Apple API claim in docs/ARCHITECTURE.md, docs/RISKS.md and docs/FEATURE_MATRIX.md against developer.apple.com. Re-tag each as [V: doc URL], or correct it. Anything that can only be confirmed on a device goes on the manual-check list in step i.

b. **project.yml and dependencies.** Done on branch `feat/project-config` (commit 7b083c3) unless marked otherwise.
   - `LSUIElement` = YES (Info.plist properties). Done.
   - `ENABLE_HARDENED_RUNTIME` on; no App Sandbox (D4). Done.
   - Hardened runtime applies to Release only for now (D11); test Automation prompts with a Release build.
   - Entitlements file, declared in project.yml, containing `com.apple.security.automation.apple-events`. Done.
   - `NSAppleEventsUsageDescription` in Info.plist properties. Done.
   - `KeyboardShortcuts` package pinned with `exactVersion:` (3.1.0, as recorded in DECISIONS.md D10a). Done. The licence (MIT) is recorded in D10a. `dependency-manager` verified the resolved pin, licence and Swift modes (D10a).
   - `fileGroups` lists CLAUDE.md, TASK.md and docs as reference-only files in Xcode's navigator (D12). Done.
   - Run `xcodegen generate`. Done.

c. **Menu-bar item.** `MenuBarExtra` with Settings… and Quit (D14). Launch at login (`SMAppService`) moved to Phase 3 Settings.

d. **NotchPanel.**
   - Borderless, non-activating `NSPanel` above the menu bar. Joins all Spaces and full-screen apps.
   - Closed state sized exactly to the notch (D5). Pill on displays without a notch.
   - One display only (D9).
   - Repositions on screen-parameter changes, debounced 200 ms.
   - Displays are keyed by `CGDirectDisplayID`, never by name.

e. **Hover state machine.** Closed → peek → open. 0.12 s open delay (was 0.3 s, retuned on device, D18), 0.1 s exit debounce, spring animations. Uses an AppKit tracking area. No polling loop.

f. **Module protocol, registry and stub module.**
   - `NotchModule` protocol and `ModuleRegistry` (ARCHITECTURE.md §3).
   - Fixed layout slots (D8).
   - One stub Now Playing module behind a `NowPlayingSource` protocol (D2), rendering a placeholder. No real sources yet.

g. **Unit tests via `test-writer`.**
   - Notch geometry (the pure `NotchGeometry` function, ARCHITECTURE.md §7).
   - Hover state machine (the pure transition function).
   - Registry start and stop on enable and disable.

h. **Build and test.** Run `xcodegen generate`, then `xcodebuild -scheme DropNotch -destination 'platform=macOS' build test`. Show the real output. Nothing is claimed as passing without it.

i. **Manual checks on a real notched Mac.** These cannot run in CI.
   - Hover at the top pixel row.
   - Clicks next to the closed notch reach the apps underneath.
   - Panel behaviour over full-screen apps and across Spaces.
   - A pointer passing straight across the notch doesn't open it; peek grows the shape while the delay runs (D18).
   - No flicker at the edge of the open panel (D18).
   - Re-entering the leftover transparent area during the close animation peeks and reopens without clipping the shape; clicks in that area during the close (D19).
   - Growing from closed shows no one-frame jump of the shape (D19).
   - Reduce Motion turns off the spring (D19).
   - Reposition when an external display is connected or removed.
   - The closed shape lines up with the hardware notch with no visible seam (fractional inset), and the root view isn't pushed down by the safe area (D16).
   - The panel never takes keyboard focus; typing in the app in front keeps working.
   - `.statusBar` level draws above the menu bar and full-screen apps; menus opened from the menu bar still draw above the panel (D16).
   - Pill on a screen without a notch (external display, clamshell), including with the menu bar auto-hidden. On a crowded menu bar, status items or menus the pill covers still behave acceptably (expected effect of D5).
   - No window or Dock icon at launch.
   - Still to confirm (D20):
     - With a display arranged directly above the notched screen, a pointer resting on that display's bottom edge over the notch doesn't trigger peek or open.
     - A slow, slightly shaky approach still opens the notch. The sweep guard measures speed from one move to the next, with no smoothing.
   - Module placeholder (D21):
     - "Nothing playing" appears when the shape opens, doesn't flicker, and disappears at once on close without poking outside the shrinking shape.
     - With Reduce Motion on, hover open and close show no flash or clipped frame, and toggling the setting mid-session works.
     - VoiceOver: the panel is named "DropNotch" (Shash, 2026-10-25; D21). Note what VoiceOver announces for it, closed and open. Not tested yet; moved to the Phase 3 accessibility checks.
   - Menu-bar Settings… opens Settings in front, with keyboard focus, while another app is frontmost (D14). ⌘Q in the Settings window quits.
   - Deferred (Shash, 2026-10-24): the step a items that can only be confirmed on a device need features outside Phase 2. Each one is checked in the phase that builds its feature:
     - Automation prompts (Release build, D11): does macOS show one prompt per target app, on the first Apple Event? Not stated in Apple docs; confirm on device.
     - Privacy grants after re-signing: does an ad-hoc rebuild re-prompt or lose grants? Not stated in Apple docs; confirm on device.
     - Clipboard (D7): under "ask" (Apple's default), does reading `changeCount` or `types` alone trigger the alert? Does `changeCount` still work under Always Deny?
     - Folder prompts: does an unsandboxed build get the Desktop, Documents or Downloads prompt on first access?
     - Downloaded DMG: is it quarantined and checked like the app?
     - Audio-tap permission prompt from a Release build (v0.2 waveform).
     - Screen capture: are our windows excluded via ScreenCaptureKit filters (Apple says not to rely on `sharingType`)?

j. **Review and records.**
   - Per branch: `test-writer` and `code-reviewer`.
   - Once, after `feat/module-registry`: `accessibility-auditor`, `performance-optimizer` and `docs-writer`.
   - No `security-auditor` in Phase 2 (Shash, 2026-10-24): c–f change no entitlements or signing, and step b's entitlements were reviewed under D13.
   - Update docs/DECISIONS.md and docs/ARCHITECTURE.md.
   - Branch 4 (`feat/module-registry`): all of the above done except the device check (step i). Outcomes are in D21, "Review".

## Out of scope for Phase 2
Now Playing real sources, file tray, clipboard, and notes modules (Phase 3). MediaRemote (v0.2). Lock screen (beyond v0.2). Sparkle. Launch at login (Phase 3 Settings).

Clipboard module (Phase 3), first step: re-run probe copies 4–6 (detection call and text reads) under the preview flag (`defaults write com.shashwat.ClipboardProbe EnablePasteboardPrivacyDeveloperPreview -bool yes`), with the probe's main-actor fix (D7b); delete the flag afterwards. See docs/research/clipboard-probe-2026-10-24.md §4.

## Phase 3 carry-overs

From the branch 4 reviews. None blocks the Phase 2 merge. Nothing here is built yet.

Accessibility (accessibility-auditor):
- L1. Hover is the only trigger. The hotkey must toggle the notch and click-to-open is needed. Release blocker (also RISKS.md §4).
- L2. The panel can never be key (D16). When controls or text fields arrive, flip `canBecomeKey` while the notch is open; this revisits D16. It brings Escape to close, a focus ring, and labels on icon-only controls.
- L3. Close behaviour for a hotkey-opened notch: Escape, the hotkey again, or focus leaving. Don't auto-close while VoiceOver focus is inside.
- L4. Post an accessibility notification on open, and group the open content under the module title.
- L5. Force a dark colour scheme on the notch content when the first real module lands.
- L6. Respect Increase Contrast. Never use colour alone to show state.
- L7. Hit targets of at least about 24 pt, kept clear of the 18 pt corners.
- L8. Optional cross-fade instead of nothing under Reduce Motion.
- Real text uses `.subheadline` or larger, not `.caption` (about 10 pt). The stub's placeholder uses `.caption`.

Performance (performance-optimizer):
- Build log strings lazily on the sweep path (`NotchState.send`, `NotchState.startTimer`, `NotchHostingView.logPointer`).
- Re-check `AnyView` identity and per-module `@Observable` state when real content lands.
- Add `NSWorkspace` screen sleep/wake pausing together with the first repeating timer or animation.
- Before release, re-measure with the pointer inside the panel, in a Release build, and over hours.

Phase 3 polish: give the open shape top corners/shoulders where it meets the menu bar, so it reads as one piece with the hardware notch (the square top corners show over the menu bar today).

## Phase 3

Branch order (Shash, 2026-10-25): `feat/now-playing-scripting` (merged), then `feat/now-playing-media` (progress bar, artwork, seek; plan approved 2026-10-25; favourite dropped, D26), then `feat/now-playing-compact` (the compact slot, with a D5 revision; reuses that artwork for "song icon left, wave right"), then `feat/hotkey` (L1–L3, release blocker).

### Branch 1: `feat/now-playing-scripting` (plan approved by Shash, 2026-10-25; merged to main 2026-10-25)

Real Now Playing for Music and Spotify: title, artist, play/pause, next, previous, in the open notch. Decisions D22 (Apple Events), D23 (permission), D24 (notifications and selection). Probe report: docs/research/now-playing-probe-2026-10-25.md.

Out of this branch: MediaRemote (v0.2), artwork and progress bar (branch 2, `feat/now-playing-media`), seek (stays MVP; not yet assigned to a branch), shuffle and repeat, the compact slot and waveform (branch 3), a custom screen before the Automation prompt (not built, D23), hotkey and keyboard focus (branch 4).

Steps, one commit each. Steps 1–14 are done.
1. Probe (not committed). Done 2026-10-25; report reviewed by Shash.
2. `docs:` this section, the probe report, D22–D24, and corrections to D21, ARCHITECTURE §3/§8/§10 and RISKS §2. Done.
3. `feat:` `Logger.nowPlaying`. Done.
4. `feat:` `Services/MediaPlayer.swift`; `NowPlayingInfo` gains `player`. Done.
5. `feat:` `Services/PlayerNotificationParser.swift` + tests. Done.
6. `feat:` `Services/NowPlayingSelection.swift` + tests. Done.
7. `feat:` `Services/AppleEventOutcome.swift` + tests. Done.
8. `feat:` `Services/AppleEventSending.swift` + `Services/AppleEventSender.swift`. Done.
9. `feat:` `NowPlayingSource.send(_:to:)`; `Services/ScriptablePlayersSource.swift` + tests. Done.
10. `feat:` open-notch view, controls, denied state, accessibility, dark scheme + tests. Done.
11. `feat:` `acceptsFirstMouse` on `NotchHostingView`. Done.
12. `feat:` `AppDelegate` uses `ScriptablePlayersSource`. Done.
13. `chore:` usage string in project.yml covers reading the current track. Done.
14. Debug build and test. **Stop before the Release build** (Shash): Shash runs the Release build and device checks. Done 2026-10-25: build and tests passed, 122 tests, 0 failures (run by the lead).

Agents (Shash, 2026-10-25): `test-writer`, `code-reviewer`, `security-auditor`, `docs-writer`. Not `performance-optimizer` (no timers; device check 12 covers idle wake-ups). `accessibility-auditor` runs once at the end of the MVP.

Reviews (done, 2026-10-25):
- `test-writer`: coverage extended.
- `code-reviewer`: Approve with changes; all applied.
- `security-auditor`: Pass with changes; M1 and L1–L3 applied, L4 recorded as a known limit in D24.
- `docs-writer`: README, ARCHITECTURE, RISKS, FEATURE_MATRIX and D24 brought up to date.

Device results (Shash, 2026-10-25, Release build on a notched Mac): Now Playing works for both Music and Spotify: title, artist, play/pause, next and previous all correct. Switching between the two players works: checks 5 and 6 passed. Checks 1–4 and 7–16 have not been tested yet. They stay open and must be run before release.

Device checks (Release build, notched Mac). Reset grants between runs with `tccutil reset AppleEvents com.shashwat.DropNotch` [I: service name not checked].
1. **Open, before release.** Spotify already playing at launch: no prompt at launch. The first click gives one prompt naming Spotify, with our usage text. Then Music, which gets its own prompt. (Settles step i "one prompt per target app".)
2. **Open, before release.** Deny: the "Allow in System Settings" state appears, track info keeps updating, nothing crashes. Turning the grant on in System Settings works without a relaunch.
3. **Open, before release.** Re-sign: does an ad-hoc Release rebuild keep the grant, re-prompt, or return -1743 silently? Do Debug and Release share a grant? (Settles step i "grants after re-signing".)
4. **Open, before release.** Never launch: quit the player and click a control straight away. It must not relaunch.
5. **Passed (2026-10-25).** Launch and quit players while the notch is open. Quitting both shows "Nothing playing".
6. **Passed (2026-10-25).** Both players playing: the selection rule in D24. Note whether each Music track change briefly shows Spotify (~70 ms).
7. **Open, before release.** Track changes reach the notch while another app is frontmost, and still do after Settings has been opened and closed.
8. **Open, before release.** The first click on a control works, DropNotch doesn't activate, and typing in the front app straight after still works.
9. **Open, before release.** Hung player: `kill -STOP <pid>`, click: the notch stays responsive and the click gives up after about 2 s. Then `kill -CONT <pid>`. If the controls stay disabled until `kill -CONT`, the hang is in the permission check (it has no timeout); record which.
10. **Open, before release.** Music: no visible flicker of the play/pause icon on pause, play or skip (D24 bursts).
11. **Open, before release.** Spotify's Previous mid-track: restart or previous track? Record it.
12. **Open, before release.** Idle wake-ups are 0 with both players running; while playing, wake-ups only on notifications.
13. **Open, before release.** Radio or a stream with no title: the notch shows the player name, never an empty or odd title.
14. **Open, before release.** A Spotify ad on the free account (empty or odd `Name`): the notch hides the title or shows the player name, never garbage.
15. **Open, before release.** Release launch, and `codesign -d --entitlements -` shows only apple-events (D11, D13).
16. **Open, before release.** Accessibility (the carry-overs from step i): VoiceOver reads the control labels and the title, Increase Contrast, Accessibility Inspector, Reduce Motion.

### Branch 2: `feat/now-playing-media` (plan approved by Shash, 2026-10-25)

**Status (2026-10-25):** steps 0–14 done; Debug clean build and tests pass (212 tests, 0 failures, run by the lead). Reviews done, required fixes applied: test-writer (artwork after an ad), code-reviewer (lost races, relaunch, VoiceOver base, a name shared with Atoll), security-auditor (JPEG/PNG only, size limits, host as written), performance-optimizer (10 fps bar, elapsed-time §9 row, screen sleep closes the notch), accessibility-auditor (live VoiceOver value, announced denial, 24 pt link, 40 % track). **Merged to main 2026-10-31.** After Shash's first Music run, a UI-feel pass (D27: optimistic play/pause, symbol morph, hover glass, crossfades) and three clip fixes (time jumps, icon flash, text overlap; D27 revision), each through test-writer and code-reviewer (final verdict Approve; 258 tests, 0 failures). Device checks 17–20 and 22 passed for Music (Shash, 2026-10-31). docs-writer runs once in the release branch (speed mode).

Progress bar with seek, and artwork, in the open notch. Decisions D25 (Spotify artwork over HTTPS, the first network access) and D26 (units, reads, merging, Core Animation bar, seek; favourite dropped). Probe report: docs/research/now-playing-media-probe-2026-10-25.md. Package search (dependency-manager, 2026-10-25): no packages.

Out of this branch: favourite (D26), shuffle and repeat, the compact slot (branch 3), an artwork on/off switch (Phase 3 Settings), a disk cache, retries, keeping the notch open while dragging the bar.

Steps, one commit each:
0. Probe (not committed). Done 2026-10-25; report reviewed by Shash.
1. `docs:` probe report, D25, D26, this section; ARCHITECTURE §8–§10, README Privacy and Permissions, RISKS §2/§4, FEATURE_MATRIX.
2. `feat:` `PlaybackPosition` and the new `NowPlayingInfo` fields + tests.
3. `feat:` parser: track ids, durations and positions in seconds + tests.
4. `feat:` selection: carry, re-anchor, stale reads, artwork by track id + tests.
5. `feat:` sender: position, duration, id and artwork-URL reads; Music artwork read.
6. `feat:` source: Music reads per state notification, Spotify reads per new track + tests.
7. `feat:` `NowPlayingArtwork` thumbnail decoding + tests.
8. `feat:` `ArtworkLoading` and `ArtworkDownloader` (D25) + tests with a stubbed `URLProtocol`.
9. `feat:` source loads artwork once per track + tests.
10. `feat:` artwork view, Core Animation progress bar, new layout.
11. `feat:` read the position each time the notch opens.
12. `feat:` seek: click and drag on the bar, VoiceOver adjust in 10 s steps + tests.
13. `chore:` usage string in project.yml.
14. Debug build and test, then the reviews. **Stop before the Release build** (Shash).

Agents: `test-writer`, `code-reviewer`, `security-auditor` (network, image decoding, Apple Event writes), `performance-optimizer` (Core Animation bar, reads per notification, decoding), `accessibility-auditor` (Shash: on this branch), then `docs-writer` after the device checks.

Device checks (Release build, notched Mac), numbered after branch 1's. Speed mode (CLAUDE.md): only 17, 18, 19, 20, 22 and 26 run on this branch; 21, 23, 24 and 25 moved to the Release checklist below.
17. **Passed for Music (Shash, 2026-10-31).** The time matches Music after play, pause and next; no backward jumps. Spotify: Release checklist.
18. **Passed for Music (Shash, 2026-10-31).** Spotify: Release checklist.
19. **Passed for Music (Shash, 2026-10-31).** Spotify: Release checklist.
20. **Passed for Music (Shash, 2026-10-31);** no app-icon flash between tracks. Spotify: Release checklist.
22. **Passed (Shash, 2026-10-31).**
26. Moved to the Release checklist (the lead checked `codesign`: only apple-events, hardened runtime on).

### Branch 3: `feat/compact-slot` (D28 approved by Shash, 2026-10-31; merged to main 2026-10-31)

**Status (2026-10-31):** device checks 27–32 passed (Shash, notched Mac, Music), after two device fixes: the pixel row of wallpaper above the wings (D29) and the 2 s grace (D28 revision). 281 tests, 0 failures. Not pushed: this clone has no `origin` remote.

While music plays, the closed notch shows the artwork on the left and decorative bars on the right. D28 revises D5. Package search: none (Core Animation and existing views only).

Steps, one commit each: 1. `docs:` D28, this section, ARCHITECTURE §7/§9. 2. `feat:` compact frames in `NotchGeometry`. 3. `feat:` registry: both slots default to the first module; `hasCompactContent`. 4. `feat:` Now Playing compact content with the grace (5 s, then 2 s); compact view and bars. 5. `feat:` `NotchState` widens and narrows the closed shape; root view draws the slots. 6. Build, test-writer, code-reviewer, device checks.

Out of this branch: slot pickers (Settings), a real waveform (v0.2), VoiceOver for the closed notch (accessibility-auditor, release branch).

Device checks (Debug build is enough: no entitlement or signing change; notched Mac, Music). **All passed (Shash, 2026-10-31):** no gap at the top edge, the bars go flat at once on a pause from Music and from the notch, the wings retract after about 2 s.
27. Play: the shape widens smoothly to about 250 pt with the artwork left and moving bars right; pause and play quickly: no flap; pause and wait: the bars freeze flat at once and the wings retract after about 2 s, the content fading with the shape; quit Music: they retract at once. Nothing shows outside the black shape at any point.
28. Hover over a wing peeks and opens the notch; closing returns to the wide shape. Move the pointer in and out while the wings are retracting: no clipped shape. With the pointer resting where a wing appears when music starts, note whether it peeks or opens unasked.
29. Menu-bar items and app menus next to the notch: note which ones the wings cover and that they work again once the wings retract.
30. The bars look smooth enough at 15 fps (if choppy, raise `preferredFrameRateRange` in `CompactWaveform.swift`). They are still while paused (flat), under Reduce Motion (uneven) and in Low Power Mode, toggled mid-song.
31. Display sleep and wake while playing: the bars move again after wake.
32. Reduce Motion: the width changes at once, with no flash or clipped frame.

Reviews: test-writer (18 tests); code-reviewer: Approve with changes. Applied: grow to the union of the old and new frames (W1), device checks listed (W2), content fades out with the wings (S3), fewer observer wakes (S4), bars restart only on a size change (S5), comments (S6, S7).

### Branch 4: `feat/hotkey` (D30; shortcut ⌃⌥N chosen by Shash, 2026-10-31; merged to main 2026-10-31)

**Status (2026-10-31):** built; test-writer (11 tests) and code-reviewer (Approve with changes; W1, W2, S1–S5 applied, W3 left to device check 36) done. 292 tests, 0 failures. Device checks 33–38 all passed (Shash, 2026-10-31, notched Mac, Debug build), including 36, so W3 needed no change. Carry-overs L1–L3 are closed, apart from the VoiceOver part of L3 and click-to-open.

A global shortcut (⌃⌥N) opens and closes the notch. Opened by keyboard, the panel takes key focus: Tab and the arrows move between the controls, Space and Return press them, Escape, the hotkey again or a click elsewhere closes it and hands focus back. Hover is unchanged and never takes focus. Package search: none (KeyboardShortcuts was pinned in Phase 2, D10a).

Out of this branch: rebinding the shortcut (Settings), click-to-open, keeping a hover-opened notch open while VoiceOver focus is inside (L3), keyboard access to the progress bar.

Device checks (Debug build is enough: no entitlement or signing change; notched Mac, Music playing). **All passed (Shash, 2026-10-31).**
33. ⌃⌥N from closed: the notch opens with play/pause showing the hover circle; Space toggles once (also when held); Tab and ←/→ move; no rectangular focus ring on the round controls.
34. Escape, and separately a second ⌃⌥N: the notch closes and you can type straight into the front app without clicking; the closed notch doesn't flicker.
35. Hover-open, then ⌃⌥N: focus appears and the notch stays open; move the pointer away: it stays open until Escape.
36. System Settings › Keyboard › Keyboard navigation on: one Tab stop per control and Space fires once (if two stops, `.focusable(false)` on the inner Button, code-reviewer W3).
37. Hover mode (no hotkey): one click on each control still works, and typing in the front app afterwards still works.
38. While opened by ⌃⌥N, click another app's window or ⌘Tab: the notch closes and that app has focus.

### Branch 5: `feat/notes` (D31; tabs chosen by Shash, 2026-10-31; merged to main 2026-10-31)

One plain-text note in its own tab, saved locally 1 s after the last edit. ⌃⌥N on the Notes tab puts the cursor in the note; Escape closes and hands focus back. Package search: skipped; Foundation and `TextEditor` cover it, and there is nothing a package would save.

**Status (2026-10-31):** built; test-writer (14 tests) and code-reviewer (Approve with changes: W1 save-failure line, W2 deleted note not written back, S1 `.focusRequested`, S2 comments applied; S3 added to check 42; S4, S5 recorded in D31). 309 tests, 0 failures. Device checks 39–44 passed (Shash, 2026-10-31, notched Mac, Debug build), apart from the input-method part of 40, which moved to the Release checklist.

Out of this branch: several notes, rich text, keeping the last tab across relaunches, Tab out of the note.

Device checks (Debug build is enough: no entitlement or signing change; notched Mac). **All passed (Shash, 2026-10-31)**, except the input-method part of 40 (not tested; on the Release checklist).
39. ⌃⌥N, ⌘2: the placeholder "Type a note" sits where the cursor is; type at once without clicking; ⌘1 and ⌘2 switch tabs and the selected icon shows a filled capsule.
40. While typing in the note, Escape: the notch closes, the front app takes typing straight away, and no completion list appears. With a Japanese or Chinese input method mid-composition, Escape cancels the composition and the notch stays open.
41. Close with ⌃⌥N and reopen: it opens on Notes with the text intact. Quit from the menu bar within 1 s of typing, relaunch: the last characters are there. `cat ~/Library/Application\ Support/DropNotch/Notes/note.txt` shows the note.
42. Hover-open, Notes tab, click in the note: the cursor appears and typing goes into the note, not the front app; moving the pointer away doesn't close it; Escape closes it. Before clicking, scroll a note longer than the editor: if it doesn't scroll, note it (the click overlay takes the scroll, code-reviewer S3).
43. Hover mode on Now Playing (no hotkey): clicking the tab icons switches tabs, controls still work with one click, and typing in the front app afterwards still works (check 37 again).
44. Now Playing still opens with play/pause focused on ⌃⌥N, ←/→ still move, and the content sits where it did before the tabs (below the camera housing, not clipped).

### Branch 6: `feat/file-tray` (D6, D32)

Drop files on the notch (closed, compact or open) to add them to a Tray tab; the notch opens on Tray while a drag is over it. Drag items out to Finder or other apps (copies only, originals stay put); AirDrop and Share for the selection, or all files when nothing is selected; remove, clear all; the tray persists across relaunches. Package search (dependency-manager, 2026-10-31): nothing worth adding, only small MIT bookmark wrappers.

**Status (2026-10-31):** built; 309 tests, 0 failures before test-writer.

Out of this branch: Quick Look and thumbnails, open/reveal in Finder, text and link drops, keyboard access to tiles and actions.

Device checks (Debug build is enough: Info.plist usage strings only, no entitlement or signing change; notched Mac).
45. Drag a file from Finder onto the closed notch, and onto a wing while music plays: it peeks, opens on Tray, the cursor shows copy (+) or link, and the dropped file appears; it is still in its Finder folder. Drop it again: no second tile. Drop one from Desktop, Documents or Downloads: note any folder prompt and its text.
46. Drag a tile into a Finder folder: a copy appears there and the original stays. Drag a tile to the Dock's Trash: refused. Click one tile, ⌘-click a second, drag both into a Mail message. Note whether the notch closes while you drag out of it and whether the drop still lands. After any drop, moving the pointer away closes the notch.
47. Drag a photo from Photos (or a Mail attachment, or an image from Safari): it appears in the tray, and `ls ~/Library/Application\ Support/DropNotch/Tray/` shows its folder; Remove deletes that folder.
48. Rename a tray file in Finder and reopen the notch: new name. Move it to the Trash and reopen: greyed with a question mark, can't be dragged, Remove works. Quit and relaunch: the tray is the same (`cat ~/Library/Application\ Support/DropNotch/tray.json`).
49. One tile selected, AirDrop: the AirDrop window comes up in front and works. Share: the share menu opens; note whether the notch closes under it. With nothing selected, both send every file.
50. Clear All: the tray is empty and the originals are still in Finder. ⌘1–⌘3 switch tabs; in hover mode one click selects a tile, and typing in the front app afterwards still works.

## Release checklist

Device checks moved here from feature branches (speed mode, CLAUDE.md). Run them in the release branch on a Release build on a notched Mac.

From branch 5, `feat/notes`:
- **Pending.** 40 (input method). With a Japanese or Chinese input method mid-composition in the note, Escape cancels the composition and the notch stays open; a second Escape closes it.

From branch 2, `feat/now-playing-media`:
- **Pending.** 17–20 for Spotify (as written above): time and bar, a seek in Spotify's window, click and drag seek with the first-seek prompt and VoiceOver adjust, Spotify artwork, an ad, and app icons without the grant.
- **Pending.** 26. Release launch, and `codesign -d --entitlements -` shows only apple-events.
- **Pending.** UI feel (D27): glass appears on hover only, in the non-activating panel, with press feedback on macOS 26+; its press bounce respects Reduce Motion; on macOS 14/15 the white hover circle appears in the non-activating panel; a late Music burst doesn't flicker the play/pause icon; artwork on a track change fades old → new directly, with the app icon only for a track without artwork or after the 2 s hold.
21. **Pending.** Network (`nettop` or a firewall): only `i.scdn.co`, at most one request per Spotify track change, none for Music, none while idle. Offline: app icon, no retries.
23. **Pending.** Energy: 0 wake-ups while closed and while paused; about 1 a second while open and playing (the elapsed time); WindowServer within about 3 points of its baseline; display sleep with the notch open closes it.
24. **Pending.** Memory stays flat over 50 track changes.
25. **Pending.** Accessibility Inspector: the bar's role and increment/decrement actions (if it isn't adjustable, switch to an AppKit slider role on `ProgressBarView`), its value after 30 s of playing; every control named; the panel reads as "DropNotch" containing a "Now Playing" group. VoiceOver speaks the announcement after a refused request. The System Settings link is a 24 pt target and the denied layout fits under the real notch. Track contrast with Increase Contrast on and off; Reduce Motion shows no jumps.
