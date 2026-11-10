# TASK: Reverse-engineering analysis + foundation

Rules, commands and constraints are in CLAUDE.md. Follow them throughout.

**Status (2026-11-10):** v0.1.0 is released. v0.2 (Home dashboard, D42–D45) is in progress in speed mode: see "v0.2" at the end. Branch 1, `feat/home`, is merged to main (2026-11-09). Branch 2, `feat/battery-card`, is merged to main (2026-11-09). Branch 3, `feat/calendar-card`, and branch 3b, `feat/home-layout` (D46), are merged to main (2026-11-09; device checks 84–94 passed on one Release build). Branch 4, `feat/quick-commands`, was built but set aside unmerged (Shash, 2026-11-10); branch 4b, `feat/terminal` (D48), is merged to main (2026-11-10; device checks 95–100 passed). `feat/notch-size` (D49) is merged (checks 101–113 passed). Next: `release/v0.2.0`.

**Phase 3 status (2026-11-01, kept for history):** release/v0.1.0 in progress: the keyboard fix (D40), reviews and DMG (D41) are done; the one device session below is next, then Shash approves the public steps. Phase 3 is in progress, in speed mode (CLAUDE.md). Branches 1, `feat/now-playing-scripting`, 2, `feat/now-playing-media`, 3, `feat/compact-slot`, 4, `feat/hotkey`, 5, `feat/notes`, 6, `feat/file-tray`, and 7, `feat/clipboard`, are merged to main and pushed to `origin`. Branches 8, `feat/settings`, and 9, `feat/polish`, are merged to main (2026-11-01). Next: release. See "Phase 3" below.

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

h. **Build and test.** Run `xcodegen generate`, then `xcodebuild -scheme DropNotch -destination 'platform=macOS' -skipPackagePluginValidation build test`. Show the real output. Nothing is claimed as passing without it.

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

### Branch 6: `feat/file-tray` (D6, D32; merged to main 2026-10-31)

Drop files on the notch (closed, compact or open) to add them to a Tray tab; the notch opens on Tray while a drag is over it. Drag items out to Finder or other apps (copies only, originals stay put); AirDrop and Share for the selection, or all files when nothing is selected; remove, clear all; the tray persists across relaunches. Package search (dependency-manager, 2026-10-31): nothing worth adding, only small MIT bookmark wrappers.

**Status (2026-10-31):** built. test-writer: 26 tests (found a /private dedupe bug, fixed). code-reviewer: Approve with changes (W1 copied empty-state string reworded, W2 promised folders and partial writes, S2, S3 AirDrop service kept, S5 applied; S1, S4 recorded in D32). security-auditor: Pass with changes (M1 symlinked item folder could turn Remove into a delete elsewhere, fixed with a test; L1 promised symlinks refused; L2–L6 recorded in D32). 335 tests, 0 failures. Device checks 45–50 passed (Shash, 2026-10-31, notched Mac, Debug build).

Out of this branch: Quick Look and thumbnails, open/reveal in Finder, text and link drops, keyboard access to tiles and actions.

Device checks (Debug build is enough: Info.plist usage strings only, no entitlement or signing change; notched Mac). **All passed (Shash, 2026-10-31).**
45. Drag a file from Finder onto the closed notch, and onto a wing while music plays: it peeks, opens on Tray, the cursor shows copy (+) or link, and the dropped file appears; it is still in its Finder folder. Drop it again: no second tile. Drop one from Desktop, Documents or Downloads: note any folder prompt and its text.
46. Drag a tile into a Finder folder: a copy appears there and the original stays. Drag a tile to the Dock's Trash: refused. Click one tile, ⌘-click a second, drag both into a Mail message. Note whether the notch closes while you drag out of it and whether the drop still lands. After any drop, moving the pointer away closes the notch.
47. Drag a photo from Photos (or a Mail attachment, or an image from Safari): it appears in the tray, and `ls ~/Library/Application\ Support/DropNotch/Tray/` shows its folder; Remove deletes that folder.
48. Rename a tray file in Finder and reopen the notch: new name. Move it to the Trash and reopen: greyed with a question mark, can't be dragged, Remove works. Quit and relaunch: the tray is the same (`cat ~/Library/Application\ Support/DropNotch/tray.json`).
49. One tile selected, AirDrop: the AirDrop window comes up in front and works. Share: the share menu opens; note whether the notch closes under it. With nothing selected, both send every file.
50. Clear All: the tray is empty and the originals are still in Finder. ⌘1–⌘3 switch tabs; in hover mode one click selects a tile, and typing in the front app afterwards still works.

### Branch 7: `feat/clipboard` (D7, D7a–D7c, D33; merged to main 2026-11-01)

A Clipboard tab (⌘4): the last 25 text, link and image items, in memory only. History starts only after "Turn On Clipboard History" in the tab. Under Always Allow it fills by itself; under Ask it never reads in the background (a read blocks the notch until the macOS alert is answered, D7c), so the tab explains and offers "Add Clipboard"; under Always Deny it shows the System Settings path. Search, ↑/↓ and Return, click to copy back; copying closes a keyboard-opened notch so ⌘V lands in the front app. Clear empties the history. Package search (dependency-manager, 2026-11-01): none worth adding.

**Status (2026-11-01):** step 0 probe re-run done (docs/research/clipboard-probe-2026-10-24.md §5, D7c; preview flag deleted). Built; test-writer (19 tests; tick consent guard and CRLF preview fixed); code-reviewer: Approve with changes (W1 Always Allow trusted only if it held at launch, W2 thumbnails, S3 wording applied; S1 kept, S2 recorded, S4 no rename). security-auditor: Pass with changes (M1 image header and 25 MP cap, M2 1M-unit text cap and stored preview, M3 Clear button, L1 legacy markers, L2 mid-read change, all with tests; L3 screen sharing recorded in D33; Turn Off moves to Settings). Automated security review: overflow-safe pixel check, with a test. 362 tests, 0 failures. Device checks 51–56 passed (Shash, 2026-11-01, notched Mac, Debug build); the notch never froze.

Out of this branch: persistence and Turn Off (Settings), deleting single items, pinning, rich text and files, hiding history while the screen is shared.

Device checks (Debug build is enough: no entitlement, Info.plist or signing change; notched Mac). **All passed (Shash, 2026-11-01).**
51. ⌃⌥N, ⌘4: four tab icons fit left of the camera housing. The turn-on text is readable; click Turn On. Copy text in Safari, a URL from its address bar, and a screenshot to the clipboard (⌘⌃⇧4): they appear newest first, with text, link and thumbnail icons. Copy a password from the Passwords app (or 1Password): it doesn't appear. Copy a file in Finder: it doesn't appear.
52. ⌃⌥N on Clipboard: the cursor is in Search and typing filters. ↑/↓ move the highlight (if they move the text cursor instead, note it). Return copies and closes the notch; ⌘V in TextEdit pastes it. Copy back the screenshot and paste it into Preview (File › New from Clipboard).
53. Hover mode: one click on a row copies it and the notch stays open; ⌘V in the front app works without clicking it first. A click in Search takes typing. Clear empties the list.
54. Ask: `defaults write com.shashwat.DropNotch EnablePasteboardPrivacyDeveloperPreview -bool yes`, relaunch. The tab shows the Ask explanation. Copy in another app: no alert, "Add Clipboard" appears, and the notch keeps opening and closing on hover. Click Add Clipboard: the macOS alert appears; Allow: the item appears.
55. In System Settings › Privacy & Security › Paste from Other Apps, set DropNotch to Always Allow while it runs. Reopen the tab: the "quit and reopen" line. Copy something: no alert, no freeze. Quit and relaunch: copies appear by themselves. Then Always Deny and relaunch: "blocked in System Settings". Afterwards `defaults delete com.shashwat.DropNotch EnablePasteboardPrivacyDeveloperPreview` and set the setting back as you like.
56. During 51–55, `log stream --predicate 'subsystem == "com.shashwat.DropNotch" AND category == "Clipboard"' --level debug` shows only "Clipboard poll started" and access changes, never content.

### Branch 8: `feat/settings` (D34; storage chosen by Shash, 2026-11-01)

A native Settings window from the menu-bar item. General: launch at login (`SMAppService`), the hotkey recorder, built-in or main display. Modules: on/off and tab order, compact-slot pickers. Privacy: Spotify artwork downloads, clipboard history on/off, keep history after quitting (text and links, off by default), Clear Clipboard History, Clear Tray. About: version, licence, third-party notices, GitHub link. Package search: skipped (D34).

**Status (2026-11-01):** built. security-auditor: Pass with changes (M1, L1–L4 applied). test-writer: 26 tests, no bugs. code-reviewer: Approve with changes (W1, S1, S5–S9 applied; S2–S4 recorded in D34, S4 for Shash). 389 tests, 0 failures. Device checks 57–65 open.

Out of this branch: module-specific settings, confirmation before Clear, saving clipboard images, an asymmetric closed shape (S3), stopping every module from being turned off (S4).

Layout change before the checks (Shash, 2026-11-01; D35): tabs and a Settings gear in one group right of the camera housing; ⌘, opens Settings while the notch has keyboard focus; the open shape widens to keep the row clear of the housing.

Device checks (notched Mac; Debug build except 57).
57. **Release build, copied to /Applications.** General › Launch at login on: DropNotch appears in System Settings › General › Login Items. Log out and in: it starts. Off in Settings: it leaves Login Items. Turn it off in System Settings, reopen the General tab: the toggle shows off.
58. With an external display set as main: "Show the notch on" Built-in ↔ Main moves the notch at once, and hover works there. With Built-in chosen, close the lid: it falls back to the main display.
59. Modules: reorder tabs and turn one off; ⌃⌥N: the tab icons follow the order, ⌘1…⌘n match, and a selected tab that was turned off falls back to the first. Turn Now Playing off while music plays: the closed notch narrows at once.
60. Compact slots while music plays: Right = Nothing leaves an empty black right wing (S3: acceptable?). Both Nothing: the notch narrows. Relaunch: the choices persist.
61. Privacy: history and Keep on; copy text, a link and a screenshot; quit and relaunch: text and link come back, the screenshot doesn't. `ls -l ~/Library/Application\ Support/DropNotch/clipboard.json` shows `-rw-------`; `tmutil isexcluded` on it says Excluded. Clear, Keep off and history off each remove the file. Artwork off: the next Spotify track shows Spotify's icon.
62. Settings from the menu bar while another app is in front: the window comes forward; no tab clips. The recorder takes a new shortcut and it opens the notch. About: the notices sheet shows the KeyboardShortcuts licence, Done closes it, the GitHub link opens the browser.
63. (D35) ⌃⌥N, then ⌘,: Settings comes to the front with keyboard focus and the notch closes. Hover-open, click the gear: Settings is in front of the app that was in front.
64. (D35) On the Air (208 pt housing), open the notch with all four modules on, with one on, and with none on: no tab or gear sits under the housing, and the gear is always at the far right. With none on, the gear still opens Settings. Send Shash's screenshot with this one.
65. (D35) VoiceOver on the gear: "Settings, button" and one hint ("Open Settings"), not "Settings" twice; the tabs still read their module names. Tab and ←/→ in Now Playing move through the same controls as before.

### Branch 9: `feat/polish` (D36–D39; branched from `feat/settings`; both merged to main 2026-11-01)

The visual and feel pass before release: shoulders where the shape meets the menu bar; the closed notch widens only on sides with content; modules that are off sit greyed at the bottom of Settings › Modules; one spacing grid, type scale, empty states and spring across the tabs; an original app icon. Shape radii (6 / 10 pt) and icon (draft A) chosen by Shash from rendered previews, 2026-11-01. Package search: skipped (SwiftUI shapes and an asset catalogue).

Out of this branch: the macOS 26 layered icon, per-module settings views, keyboard access to Tray and Clipboard buttons, a VoiceOver element for the closed notch (Release checklist).

Reviews: accessibility-auditor: applied the selection edge (3:1, stronger under Increase Contrast), one VoiceOver group per module around every tab incl. empty states, "Copied" announcement, missing tray file dims only its icon, tooltips on tabs and tray actions, highlighted clipboard row is Selected, Settings rows don't slide under Reduce Motion. performance-optimizer (Debug, closed and idle, clipboard history on, 62 s): CPU 0.0 %, about 9 context switches a second (the 0.5 s clipboard poll), footprint 20 MB → 19.6 MB; no High findings. M1 (Tray refreshes on each switch to its tab) kept: a different module's `AnyView` already re-ran `onAppear` before `.id`. Its human checks (energy while playing, tab switching with tray files on a slow drive, memory over a day) join the Release checklist energy and memory items. test-writer: 18 tests, then 5 for D39 (opacity table, 50 % grey is 5.28:1) (one-sided frames, shoulders, NotchShape, off modules last); found one-sided wings half a point off at 1x with a fractional inset (fixed: each side trimmed by its own snapped wing). 412 tests, 0 failures. code-reviewer: Approve with changes, no W findings; applied S1 (shape placed from the canvas's leading edge, whole points), S2 (D36 click-strip size), S3 (one defaults write), S4 (script runs from anywhere, cleans up), S5 (one initialiser form); S6 (pure test of NotchState's frame choice) skipped. D39 review: Approve with changes; W1 (row at least 28 pt so the dot clears the module without a notch), S1–S5 applied. Clean-room grep: `NotchShape` name and an `AnimatablePair` of two radii also appear in Atoll; the path is built differently (tangent arcs with shoulders), judged not copied.

Device results (Shash, 2026-11-01): 66–71 passed except the selection highlight (filled capsule with an edge), which Shash disliked; replaced by the Dock-style dot (D39), chosen from rendered previews.

Device checks (Debug build is enough: project.yml gains only the icon setting, no entitlement or signing change; notched Mac).
66. Play music, then hover-open and close a few times, with each of the four tabs selected: the shoulders flow out of the menu bar with no seam or step against the hardware notch (compact, peek, open), no bounce, nothing feels slow. On close the content vanishes at once and nothing pokes outside the shrinking shape (code-reviewer device check 1: the tab cross-fade sits inside the open overlay).
67. Settings › Modules while music plays and the notch is closed: Left = Now Playing, Right = Nothing → only the left wing shows and the right side is flush with the hardware notch; swap to Right only; then both Nothing → it narrows to the notch. No clipped frame mid-animation. With the notch compact or open, click the menu bar a few points beside the shape: note whether the click reaches the menu bar.
68. Settings › Modules: turn Notes off → its row slides to the bottom, greyed, arrows disabled; turn it on → it becomes the last of those on; ⌃⌥N: the tab icons and ⌘1… follow the list. With Reduce Motion on, the row moves without sliding.
69. All four tabs: the same side margins and bottom spacing; empty states for Now Playing (quit Music and Spotify), Tray (Clear All), Clipboard (off, then on with nothing copied, then a search with no matches). The selected tab, tray tile and highlighted clipboard row have a thin edge; with Increase Contrast it is brighter. ⌘1–⌘4 cross-fade.
70. App icon: Finder › Get Info on the built DropNotch.app, the Settings window's About tab, and System Settings › Login Items show the drop-into-notch icon (if Finder shows a generic icon, `touch` the app and relaunch Finder). No Dock icon at launch.
71. VoiceOver on: ⌃⌥N on each tab reads the module name as a group (also on the Now Playing empty state); in Clipboard, Return on a row says "Copied"; hovering a tab or a tray action shows a tooltip.
72. **Passed (Shash, 2026-11-01).** (D39) The selected tab icon is white with a small dot below it and the others grey; the dot doesn't touch the module content or the camera housing. Select tray tiles (click, ⌘-click): each selected tile shows a dot inside its bottom edge, the others' names dim; nothing is clipped. ⌃⌥N on Clipboard: the highlighted row has a dot at its left edge and the other rows dim; hover-opened, all rows are white. On an external display without a notch, the dot sits under the tab and clear of the module. Increase Contrast on: the grey is visibly brighter and the dot remains.


### Branch 10: `release/v0.1.0` (Shash, 2026-11-01)

1. Keyboard access to File Tray and Clipboard buttons (D40). Done: test-writer (9 tests), code-reviewer (Approve with changes; W1 disabled actions out of the Tab order, S1 Add Clipboard focus, S2 script documented: applied), accessibility-auditor (finding closed in code). Clear All made a Tab-only stop (Shash; D40 revision, 3 tests; 429 tests, 0 failures).
2. Reviews: security-auditor Pass with changes (L1 home path in a research note fixed, still in commit d386354's history; L2 SHA-256 added). dependency-manager Pass. performance-optimizer: no findings (static; measurements below). docs-writer: README, ARCHITECTURE, FEATURE_MATRIX, RISKS. 426 tests, 0 failures.
3. DMG (D41): `scripts/make-dmg.sh` → build/DropNotch-0.1.0.dmg + .sha256; app, Applications link, LICENSE, THIRD_PARTY_NOTICES. Checked by the lead: adhoc + runtime flags, only apple-events, no get-task-allow, `codesign --verify --deep --strict` passes, `spctl` rejects (expected). CHANGELOG.md via changelog-agent.
4. Public steps prepared, not run: they wait for Shash.

Measured by the lead during the session, once the Debug build is quit (performance-optimizer's commands): idle CPU and wake-ups closed (history off, then on: about 2 a second from the poll, so item 23's "0" applies with history off only), open and playing, footprint over 50 Spotify track changes, `nettop` while idle and per track (only i.scdn.co), `codesign` on the installed app (26).

Measured by the lead (2026-11-01, Release build from the DMG, installed in /Applications, notch closed, clipboard history on, 60 s): CPU 0.0 %, 1 idle wake-up, about 8 context switches a second (the poll), footprint 21 MB; `nettop` showed no network rows. Not measured: history off, open and playing, 50 track changes, network per Spotify track. Stopped because `clipboard.historyOn` still read 1 after the Privacy switch was turned off (read with `defaults` and `plutil`; Shash to confirm after quitting and reopening: if the switch comes back on, the off isn't saved and goes to the debugger agent before release). The README states only the closed, history-on numbers.

Device session (Shash, one sitting; Release build from the DMG on a notched Mac; quit the Debug build first). Each item groups the checklist entries in brackets.
R1. Install. Quarantine a copy (`xattr -w com.apple.quarantine "0081;$(printf %x $(date +%s));Safari;" build/DropNotch-0.1.0.dmg`), open it: the window shows the app, Applications, LICENSE, notices. Drag to Applications, open: follow README › Install word for word and note any wording that differs. No Dock icon. Launch at login on, log out and in (57).
R2. Automation, Music and Spotify (1–4, 7, 8): `tccutil reset AppleEvents com.shashwat.DropNotch` first. No prompt at launch; one prompt per player on the first click; Deny shows the System Settings link and turning it on works without relaunch; quit a player, click: no relaunch; first click works and typing in the front app continues. Re-signing: reinstall a fresh DMG build and note whether the grant survives.
R3. Spotify (17–20, 14, 11) and Music flicker (10): time and bar, seek in Spotify and in the notch (click, drag), artwork, an ad on the free account, Previous mid-track (record restart or previous); Music: no play/pause flicker on skip.
R4. Keyboard (D40): ⌃⌥N, ⌘3 Tray with 3 files: first tile has a visible focus ring, not clipped; Tab and ←/→ go through tiles and enabled actions only; holding → stops before Clear All, Tab reaches it, ← from it goes back; Space toggles a tile's dot; Return on Share opens the menu below it and AirDrop or Mail works; Remove moves focus to the first tile. ⌘4 Clipboard: off → Return turns on; Tab from Search reaches Add Clipboard and Clear, Return presses; Clear returns focus to Search. Repeat with Keyboard navigation on: one stop each, Space fires once. Hover mode: one click on Share, Remove, Clear All and Clipboard Clear still works; with a hover-opened notch the Share menu opens.
R5. VoiceOver (16, 25, 71, Release checklist): ⌃⌥N on each tab reads the module group; tiles read "name, button"; VO-Space on Share opens a readable menu and Escape returns to Share; the bar is adjustable in the Accessibility Inspector; note what the closed notch announces (known: nothing).
R6. Contrast and motion (69, Release checklist): Increase Contrast and Graphite accent: focus rings and the dot visible; Reduce Motion: ⌘1/⌘2 only cross-fade, Settings rows don't slide.
R7. Settings (58–65): external display Built-in ↔ Main; module order and off; compact-slot pickers persist; clipboard Keep on/off with `ls -l` and `tmutil isexcluded`; Spotify artwork off; recorder takes a new shortcut; About › notices sheet; ⌘, and the gear open Settings in front; on the Air no tab or gear under the housing; VoiceOver reads the gear once.
R8. Edge cases (9, 13, 40): `kill -STOP` a player, click (gives up in about 2 s), `kill -CONT`; a radio stream with no title shows the player name; Japanese or Chinese input mid-composition in Notes: Escape cancels it and the notch stays open.

## Release checklist

Device checks moved here from feature branches (speed mode, CLAUDE.md). Run them in the release branch on a Release build on a notched Mac.

For v0.2.0 (not run; listed under Known limitations in the 0.2.0 notes): 77 (VoiceOver on Home), 78 (Larger Text and every card off), 83 (VoiceOver on the Battery card), and the battery and calendar pending items in the v0.2 section below.

From branch 9, `feat/polish` (accessibility-auditor, 2026-11-01; not fixed on the branch, decide before release):
- **Closed in code by D40; not re-checked on a device for 0.2.** (Was: Open (High).) File Tray has no keyboard path: tiles can't take focus, the actions are Tab stops only with Keyboard navigation on, and the hotkey sets no first focus. Same for Clipboard's Turn On, Add Clipboard and Clear (Medium).
- **Open (Medium).** VoiceOver finds nothing in the closed or compact notch (no element or open action); also the start of click-to-open. No announcement on open or ⌘N tab switch (L4); copy-back now says "Copied".
- **Pending.** VoiceOver with ⌃⌥N on each tab and the closed notch; Increase Contrast on the selected tab, tile and row; Reduce Motion: ⌘1/⌘2 only cross-fade, Settings rows don't slide.

From branch 7, `feat/clipboard`:
- **Pending.** Energy with history on: about 2 wakes a second from the poll and none while the screens sleep; CPU idle otherwise. Memory stays under about 60 MB of images after 25 large screenshots.
- **Pending.** VoiceOver reads each row's preview with the "Copies to the clipboard" hint; the Clipboard group is labelled; Increase Contrast shows the highlight.

From branch 5, `feat/notes`:
- **Pending.** 40 (input method). With a Japanese or Chinese input method mid-composition in the note, Escape cancels the composition and the notch stays open; a second Escape closes it.

From branch 2, `feat/now-playing-media`:
- **Pending.** 17–20 for Spotify (as written above): time and bar, a seek in Spotify's window, click and drag seek with the first-seek prompt and VoiceOver adjust, Spotify artwork, an ad, and app icons without the grant.
- **Pending.** 26. Release launch, and `codesign -d --entitlements -` shows only apple-events (since D44: apple-events and personal-information.calendars).
- **Pending.** UI feel (D27): glass appears on hover only, in the non-activating panel, with press feedback on macOS 26+; its press bounce respects Reduce Motion; on macOS 14/15 the white hover circle appears in the non-activating panel; a late Music burst doesn't flicker the play/pause icon; artwork on a track change fades old → new directly, with the app icon only for a track without artwork or after the 2 s hold.
21. **Pending.** Network (`nettop` or a firewall): only `i.scdn.co`, at most one request per Spotify track change, none for Music, none while idle. Offline: app icon, no retries.
23. **Pending.** Energy: 0 wake-ups while closed and while paused; about 1 a second while open and playing (the elapsed time); WindowServer within about 3 points of its baseline; display sleep with the notch open closes it.
24. **Pending.** Memory stays flat over 50 track changes.
25. **Pending.** Accessibility Inspector: the bar's role and increment/decrement actions (if it isn't adjustable, switch to an AppKit slider role on `ProgressBarView`), its value after 30 s of playing; every control named; the panel reads as "DropNotch" containing a "Now Playing" group. VoiceOver speaks the announcement after a refused request. The System Settings link is a 24 pt target and the denied layout fits under the real notch. Track contrast with Increase Contrast on and off; Reduce Motion shows no jumps.

## v0.2: Home dashboard (plan approved by Shash, 2026-11-09)

Decisions D42–D45; mock-up docs/mockups/home-v0.2.html (Air, 208 pt housing: cards 225 · 142 · 105 × 106 pt). Speed mode (CLAUDE.md): per branch build → test-writer → code-reviewer → stop for device checks; security-auditor on calendar-card and quick-commands. Docs-writer, performance-optimizer and accessibility-auditor run once, in the release branch.

### Branch 1: `feat/home` (D42)
Steps: `homeCard` and `HomeCardSize`; registry (cards aren't tabs, `homeCards`, moves within a group, new ids at their default index, compact-slot default skips modules without a compact view); `HomeModule`, `HomeView`, `HomeLayout`; Now Playing as the wide card; Settings › Modules sections. No permissions, no entitlement: Debug build is enough.

**Status (2026-11-09):** built. test-writer: 16 tests (HomeLayout; registry cards, moves, v0.1 order, slot default), no bugs. code-reviewer: Approve with changes (W1 artwork follows the card's height; S1–S5 applied; D42 Review). 445 tests, 0 failures. Offscreen render of the row at the Air's and a 14" MacBook Pro's card height checked by the lead (artwork 54 pt, then smaller; nothing clipped). Device checks 73–76 passed (Shash, 2026-11-09, MacBook Air M3, macOS 27.0.1, Debug): the card matches the mock-up, 54 pt artwork is big enough, no time text is fine. 77 and 78 were not reported (the report kept the template text); both move to the release checklist. Merged to main 2026-11-09.

Device checks (notched Mac, Debug build):
73. ⌃⌥N opens Home first with play/pause focused. ⌘1 is Home, ⌘2 Notes. On the Air: 536 pt, nothing under the housing.
74. Upgrade with v0.1 settings: Home is first, Now Playing has no tab, and the wings still appear while playing.
75. Settings › Modules: Now Playing is under "Home cards". Off removes the card and the wings; on brings both back. The arrows reorder within each section.
76. Screenshot of Home next to the mock-up, playing and with nothing playing. Is the 54 pt artwork big enough (D42)? On macOS 26, the hover glass circles on the three 28 pt controls don't touch. With Automation denied for the player, the "Allow control…" link wraps to two lines and doesn't push the control row.
77. VoiceOver: ⌃⌥N reads "Home", then a "Now Playing" group; Tab and ←/→ reach the three controls; the bar is adjustable.
78. Displays › Larger Text (or a 14"/16" MacBook Pro): Home's cards keep padding top and bottom, the artwork is smaller, nothing is clipped. Turn every card off: "Turn on a Home card in Settings".

### Branch 2: `feat/battery-card` (D43)
**Status (2026-11-09):** built. IOKit power sources behind `BatterySource`; narrow card with ring, percentage, Charging / On power / Mac, red below 20 %; not registered without a battery. Live reading checked by the lead on the Air (80 %, on power, not charging) and an offscreen render of five states. test-writer: 22 tests, no bugs. code-reviewer: Approve with changes (W1, S1–S3, S5–S8 applied, S4 recorded in D43). 469 tests, 0 failures. No permission or entitlement: Debug build is enough. Device checks 79–82 passed (Shash, 2026-11-09, MacBook Air M3, macOS 27.0.1, Debug); 83 not run, moved to the release checklist. Merged to main 2026-11-09.

Device checks (notched Mac, Debug build):
79. Home on the Air: Battery is the right-hand card; its percentage matches the menu-bar battery; at the highest charge you can reach, the percentage doesn't touch the ring.
80. Notch open: unplug and replug. The label switches between "Mac", "Charging" and "On power" within a second or two, without reopening. At a charge limit or full on the adapter: "On power", no bolt.
81. Notch closed: unplug or replug, then open: the card shows the new state at once.
82. Settings › Modules: Battery is under "Home cards" after Now Playing. Turn it off and on about 5 times, then plug or unplug: no crash and the card follows.
83. VoiceOver on the card: "Battery", then "N%, Charging" / "On power" / "On battery".
### Branch 3: `feat/calendar-card` (D44; entitlement: Release build and Release launch; security-auditor)
**Status (2026-11-09):** built. EventKit behind `CalendarSource` (store in a private actor, lazy); medium card with a one-line header, all-day line, next events, "No more events today" / "No events today" + "Tomorrow", "+N", titles toggle in Settings › Privacy; prompts only from Allow or the Settings toggle. Deviations from the mock-up and D44 are in D44 "As built". test-writer: 34 tests, no confirmed bugs; its two possible races fixed with tests (each fails without its guard). code-reviewer: Approve with changes (W1–W3, S2–S8 applied; S1 a known limit for Shash). security-auditor: Pass with changes (L1–L3 applied; L4 usage string left for Shash; L5 device check 89; a High-rated note for quick commands recorded in D45). 506 tests, 0 failures. D11 check by the lead on the final code: clean Release build, flags=0x10002(adhoc,runtime), entitlements apple-events + personal-information.calendars, `codesign --verify --deep --strict` passes, usage string in Info.plist, Release app launched and ran about 6 s, quit cleanly. Device checks 84–89 passed (Shash, 2026-11-09, MacBook Air M3, macOS 27.0.1, Release build of `feat/home-layout` at c04390a). Merged to main 2026-11-09.

Device checks (notched Mac, **Release build**: `xcodebuild -scheme DropNotch -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData build`, then open build/DerivedData/Build/Products/Release/DropNotch.app; quit the Debug build first):
84. `tccutil reset Calendar com.shashwat.DropNotch`, launch: no prompt at launch or on opening the notch; the card shows Allow Calendar. Click it: the prompt comes to the front with our text ("DropNotch shows your upcoming events in the notch. …"), even though the notch doesn't take focus. Allow: events appear without reopening.
85. Reset again. Settings › Modules: turn Calendar off and on: exactly one prompt. Deny: the card shows "Allow in System Settings", which opens the Calendars pane; turning the card off and on again doesn't prompt.
86. While DropNotch runs, turn its Calendars access off in System Settings and reopen the notch: the denied state (note whether macOS quits DropNotch). Turn it on and reopen: events load without a relaunch (code-reviewer W2).
87. Real calendars: a declined invitation and a cancelled event are hidden; each occurrence of a repeating event shows; the all-day line sits above the timed rows; calendar colours; after the last event, "No more events today" then "Tomorrow …". Settings › Privacy › Show event titles off: times and "All day · N" only. Clicking the card (or Return with ⌃⌥N focus) opens Calendar. VoiceOver reads the rows, "N more events today" and "Opens Calendar".
88. Layout: moved to 91 (the header is stacked again on `feat/home-layout`, D46). During 84–87, `log stream --predicate 'subsystem == "com.shashwat.DropNotch" AND category == "Calendar"' --level debug` shows only access states and counts, never titles or times.
89. With access granted, rebuild Release (a new cdhash) and launch: note whether the card still has access, whether events load, and what System Settings shows (security-auditor L5).
### Branch 3b: `feat/home-layout` (D46; on top of `feat/calendar-card`)
Open height 190 pt for every tab; Battery off by default; Calendar card 40 %; Now Playing artwork without the 54 pt cap and the time under the bar; stacked calendar header. Mock-up: docs/mockups/home-layout-v0.2.html (+40 and Wider chosen by Shash, 2026-11-09).

**Status (2026-11-09):** built. test-writer: 15 tests, no bugs. code-reviewer: Approve with changes (W1 time fallback, S1–S4 applied, S5 left to 94). 523 tests, 0 failures. Device checks 90–94 passed (Shash, 2026-11-09, MacBook Air M3, macOS 27.0.1, Release build at c04390a). Merged to main 2026-11-09.

Device checks (Release build of `feat/home-layout`, the same one as 84–89):
90. On the Air every tab (Home, Notes, Tray, Clipboard) opens at the same height (about 40 pt taller than v0.1), with no jump when switching tabs; nothing under the housing; hover out still closes it. Clipboard shows 5 rows; Tray has empty space under its actions (expected, D46).
91. Home next to the mock-up: two cards, Now Playing wide and Calendar about 195 pt. Calendar: weekday over the date, "+N" at the right, up to 5 rows; how much of a "Tomorrow" title shows. An event from yesterday evening to later today (make one in Calendar) shows "Now".
92. Now Playing: the artwork is about 89 pt; elapsed and total time under the bar match Music, tick while playing and stop on pause; clicking and dragging on the bar still seeks, and the time follows a drag. Turn Battery on and play a track over 10 minutes: the total time drops out rather than both times showing "0:…" (code-reviewer W1).
93. Battery default: before launching, `defaults read com.shashwat.DropNotch module.battery.enabled` (check 82 probably saved a value; note it). Then `defaults delete com.shashwat.DropNotch module.battery.enabled`, relaunch: Battery is off in Settings › Modules and Home shows two cards. Turn it on: three cards, Battery at the right, and the Now Playing title still shows.
94. VoiceOver on Home: the Calendar header reads the weekday, "N more events today" and the date; the bar still reads "Playback position, X of Y".

### Branch 4: `feat/quick-commands` (D45; not merged)
Built and reviewed (2026-11-10), then set aside by Shash (2026-11-10) for a real terminal in the notch: the branch stays as it is, unmerged. Only its D47 commit (Application Support folder 0700) was cherry-picked to main (755961f).

### Branch 4b: `feat/terminal` (D48; SwiftTerm; security-auditor; Release build)
**Status (2026-11-10):** decisions 1–8 made by Shash (D48). Built through step 12 (SwiftTerm, width, key routing, top-row accessory, LoginShell, session, module, Settings › Terminal, README); 561 tests, 0 failures. Texts approved with edits and built in. test-writer: 16 tests, found the missing key-owner conformance (fixed). code-reviewer: Approve with changes (W1, W2, S1–S5, S7 applied; S6 not taken). security-auditor on the code: Pass with changes (L-A–L-F applied). 584 tests, 0 failures (2 secure-input tests skip while another process holds secure input). Device checks 95–100 passed (Shash, 2026-11-10, MacBook Air M3, macOS 27.0.1, Release build at e9e3766); Now Playing needed Music access allowed again, because an ad-hoc rebuild is a new identity to macOS (D11). The commit scan that hit HTTP 429 was rerun on the whole branch: no findings. Merged to main 2026-11-10. Mock-up: docs/mockups/terminal-v0.2.html (Layout A: "zsh" and End Session in the strip left of the housing; SF Mono 11 pt gives 71 × 11 at 536 pt, 80 × 11 at 596 pt).

Dependency (dependency-manager, 2026-11-10): SwiftTerm `exactVersion: 1.99.3` (MIT; pre-2.0). Its library target runs a build-tool plugin, so `xcodebuild` needs `-skipPackagePluginValidation` and Xcode needs "Trust & Enable" once; PR #808's Xcode 27 failure didn't reproduce on 27.1 [V: probe]. `LocalProcessTerminalView.clipboardRead` hands the clipboard to any program in the terminal (OSC 52), so the plan replaces its `terminalDelegate`.

Plan (planner, 2026-11-10; one commit per step):
1. docs: D48 (supersedes D45's SwiftTerm paragraph; licence, pin, build plugin, clipboard seam, DropNotch's permissions for child processes); ARCHITECTURE §2, §3, §6, §9, §10.
2. chore: SwiftTerm in project.yml and THIRD_PARTY_NOTICES.md; `-skipPackagePluginValidation` in README, docs/RELEASING.md, scripts/make-dmg.sh, TASK.md, CLAUDE.md and the agent files (Decision 5).
3. feat: the open width follows the tabs (D45 Q5), ported from db17f72: `NotchGeometry(topRowItems:)`, `NotchState.setTopRowItems`, `AppDelegate.followTabCount`; the registry's tab-limit assert removed.
4. feat: panel key routing: a pure `NotchKeyRoute` and a `NotchKeyOwner` marker. With the terminal focused, Escape goes to the shell; ⌘C, ⌘V and ⌘A act on the terminal; ⌘1–9 and ⌘, still reach the tabs and Settings; other ⌘ keys (⌘Q, ⌘W, ⌘H, ⌘M) are swallowed, since SwiftTerm otherwise sends them to the app's menu.
5. feat: a module's accessory in the top row left of the housing (132 pt at 536, 162 pt at 596).
6. feat: `LoginShell`: `getpwuid` `pw_shell`, used if absolute, listed in /etc/shells and executable, else /bin/zsh; argv0 `-zsh`; home folder from the account; a fresh allow-listed environment (TERM, COLORTERM, TERM_PROGRAM, HOME, USER, LOGNAME, SHELL, a base PATH that the login shell extends, LANG, TMPDIR, SSH_AUTH_SOCK), never DropNotch's own.
7. feat: `TerminalSession` protocol (tests never spawn a shell) and a pure `TerminalHangUp.targets` that never signals DropNotch's own process group.
8. feat: `SwiftTermSession` and `NotchTerminalView` (subclass of `LocalProcessTerminalView`): our `terminalDelegate` refuses OSC 52, forwards the rest; black background in Light mode too; steady caret; copy only with a selection; End Session sends SIGHUP to the shell's and the foreground job's process groups, then SIGKILL after 2 s.
9. feat: `TerminalModule` (off by default; shell starts on the tab's first appearance; `.notStarted`/`.running`/`.ended`; Start New Session; `stop()` hangs up), `TerminalExpandedView` (keeps the same view across closes), `TerminalTopRowView`, `Logger.terminal` (never typed text, output, titles, directories or the environment).
10. feat: registered after Clipboard.
11. feat: settings: font 10–14 pt (default 11), scrollback 1,000 / 5,000 / 10,000 (default 1,000), the permissions text.
12. docs: README.
13. Build, tests, Release build and launch (D11), stop for device checks.

Decisions for Shash: (1) where the font and scrollback settings go: a Settings › Terminal tab (recommended); (2) OSC 52 writes from programs (vim, tmux yank): refuse, like reads (recommended), or allow writes only; (3) confirm before ending a running command: no for v0.2 (recommended); (4) reword the folder and Automation usage strings to mention the Terminal tab: yes (recommended); (5) approve adding `-skipPackagePluginValidation` to CLAUDE.md and three agent files.

Design review (security-auditor, 2026-11-10): sound with changes, needs Shash's decisions. H1 the Calendars usage string ("only reads your calendars") becomes untrue, and folder and Automation prompts caused from the terminal would show tray or Music text: reword all five, add a local-network string, and show a one-time sheet listing DropNotch's current grants when Terminal is first turned on. M1 SwiftTerm doesn't close DropNotch's descriptors before `execve` [V: probe]: set close-on-exec on fds ≥ 3 before starting, and on the pty master. M2 `nohup`/`disown` jobs outlive the session and DropNotch, still credited to it [V: probe]: at quit, SIGHUP, wait up to 1 s, SIGKILL; disclose. M3 stricter hang-up targets (> 1, never our own group or pid, same session id, re-read the foreground group). M4 dotfiles and Homebrew tools run with DropNotch's grants whenever a session starts: start the shell only on an explicit open (click, ⌘N, hotkey), never on hover; accept the rest in D48. M5 pin SwiftTerm (and KeyboardShortcuts) by commit and check the resolved package list before building with `-skipPackagePluginValidation`. M6 hollow caret when keys aren't going to the terminal. Lows: secure keyboard entry while focused (L1), refuse OSC 52 writes (L2), ⌘V under Ask (L3), multi-line paste documented (L4), no SwiftTerm host logging; README mentions ~/.zsh_history (L5), `TERM_PROGRAM=DropNotch`, argv0 from the shell's name (L6), screen watchers (L7), parser advisories at release (L8), entitlements unchanged (L9). Already right [V]: OSC 52 refused through the delegate seam; Kitty clipboard and media reads off; title reports empty; no input echo from status queries; paste control bytes neutralised; links need ⌘-click.

Device checks (MacBook Air, **Release build** of `feat/terminal`; Clipboard on; run the shell commands in the DropNotch terminal unless it says Terminal.app):
95. **Notice, width, start.** Settings › Modules › Terminal on: the notice appears with the approved text (its Calendars line matches your access). Cancel leaves it off; turn it on again and choose Turn On Terminal: on, and it never asks again; Settings › Terminal shows the same text. The open notch is 596 pt; "zsh" and End Session sit left of the housing without touching it. Hover-open with Terminal selected: Start Session shows and no shell starts (Terminal.app: `pgrep -P $(pgrep -x DropNotch)` prints nothing). Click the tab: the shell starts. `echo $0` → `-zsh`; `pwd` → your home; `echo $TERM_PROGRAM` → DropNotch; `env | grep -c DYLD` → 0; `brew --version` works; `stty size` → `11 80`.
96. **Keys while focused.** Click into the terminal: the caret turns solid and the notch stays open when the pointer leaves. Escape in `vim` or `less`, ↑ for history, ⌃C on `sleep 100` and Tab completion all work. ⌘Q, ⌘W, ⌘H and ⌘M do nothing (DropNotch keeps running). ⌘1 and ⌘2 switch tabs and ⌘, opens Settings. Hover-opened instead: the caret is hollow and typing goes to the app in front.
97. **Focus leaving, secure input, other shortcuts.** In Terminal.app, `ioreg -l -w 0 | grep -c SecureInputPID` is 1 or more while the DropNotch terminal is focused, and 0 after each of: a click outside, ⌃⌥N, switching tab, End Session, Quit. After using the terminal, ⌃⌥N still opens and closes the notch, and other apps' shortcuts work (Spotlight ⌘Space, ⌘⇧4, a text expander if you use one).
98. **Lifetime.** Run `top`, close the notch and reopen it: `top` is still running. End Session: Start New Session shows, and Terminal.app's `ps -axo pid,command | grep -E '[t]op$'` is empty. Start New Session, run `sleep 999 | (trap '' HUP; sleep 999)`, End Session: both `sleep`s are gone within 2 s (`pgrep sleep`). `exit` shows Session ended. Turning the tab off, and Quit, each end a running `top`. `nohup sleep 999 &` then Quit: that `sleep` survives (as documented); end it with `pkill sleep`. `kill -9` DropNotch with a session open: the shell is gone.
99. **Clipboard and settings.** Select text, ⌘C, paste in TextEdit; copy in TextEdit, ⌘V in zsh. ⌘C with nothing selected leaves the clipboard as it was. `printf '\e]52;c;?\a'` prints nothing; `printf '\e]52;c;aGk=\a'` leaves the clipboard unchanged. Settings › Terminal: 13 pt resizes live and `stty size` changes; scrollback 1,000: after `seq 5000`, scrolling up stops near 4000. In Light mode the terminal stays black.
100. **Permissions.** Note each prompt's text and the app it names: `ls ~/Desktop` (if not already allowed), `osascript -e 'tell application "Finder" to name of startup disk'`, `dns-sd -B _ssh._tcp` (local network; ⌃C to stop). `osascript -l JavaScript -e 'ObjC.import("EventKit"); $.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent)'` prints 3 if Calendars is allowed for DropNotch. `lsof -p $$ | awk '$4 ~ /^[0-9]+[urw]/ {print $4}'` lists only 0, 1, 2 and zsh's own (10 and up). Throughout, Terminal.app's `log stream --predicate 'subsystem == "com.shashwat.DropNotch" AND category == "Terminal"' --level debug` shows no typed text or output.

### Branch 4c: `feat/notch-size` (D49)
Settings › General › Notch size: Standard or Large (+40 pt high, +80 pt wide, text one step up), picked by Shash from docs/mockups/notch-size-v0.2.html.

**Status (2026-11-10):** merged to main; device checks 101–113 passed. test-writer: 6 tests, two gaps fixed. code-reviewer: Approve with changes (W1–W3, S1–S8 applied). 597 tests, 0 failures. Release build running for the checks below.

Device checks (MacBook Air, **Release build** of `feat/notch-size`; Clipboard and Terminal on):
101. **Large.** Settings › General › Notch size › Large. Open the notch: about 80 pt wider and 40 pt taller (676 × 230), the tabs clear of the housing; turn Clipboard off: 616 pt wide. Home: 6 calendar rows, artwork about 124 pt, larger title, time and controls. Go through every tab (Notes, Tray with its buttons, Clipboard, Terminal; Battery on, if you like): larger text, nothing clipped by the rounded corners. Quit and relaunch: still Large.
102. **Switch while open, with music playing.** Play a track. Open Settings › General, then hover-open the notch on Home and leave the pointer resting on it. With the keyboard, switch the size both ways (Tab to Notch size, then the arrow keys): the notch stays open and redraws at the new size each time; the track keeps playing, the bar and time keep moving, and play/pause and seek still work.
103. **Switch with a terminal session running.** In the Terminal tab, run `stty size` (11 80 at Standard, 11 pt font), then `top`. Switch to Large with the notch open (as in 102) or closed: `top` redraws to the larger grid without a restart; quit it and `stty size` shows 14 92. Switch back: 11 80. The session keeps running throughout.
104. **Switch while closed.** With music playing (the wings showing), switch the size: the closed notch and its wings don't change. Hover-open: it opens at the new size; hover out closes it as before.
105. **Keyboard at Large.** ⌃⌥N opens Home with play/pause focused; Tab moves through the controls and the focus rings aren't clipped; ⌘1… switch tabs; Escape closes.
106. **Standard unchanged.** Switch back to Standard: every tab looks exactly as before this branch (596 × 190 with six top-row items, 5 calendar rows).

**Fix (2026-11-10, Shash's report after 101–106 passed):** the pointer leaving didn't close a notch that had keyboard focus. Root cause and the new rule in D49's revision (also D48). 602 tests, 0 failures. Device checks on a Release build, this fix only:
107. **Hover out on Home.** Hover-open on Home, move away: it closes after about 0.1 s. Then ⌃⌥N on Home (play/pause focused), move the pointer in and out: it closes, and typing goes to the app in front.
108. **After clicking into the terminal.** Click into the terminal, run `top`, move the pointer away: it closes; in Terminal.app `ioreg -l -w 0 | grep -c SecureInputPID` is 0; reopen: `top` still running. Selecting text in the terminal and dragging past the edge, or dragging a tray file out to Finder, keeps it open until you let go.
109. **After ⌃⌥N.** ⌃⌥N with the pointer away: it stays open. Move the pointer in and out: it closes. ⌃⌥N again: it opens with keyboard focus (not a press that does nothing). Escape and a click in another app still close it.
Checks 107–109 passed (Shash, 2026-11-10, Release 2901a55). Then 1 s to come back while the notch has keyboard focus (Shash):
110. **Drift with focus.** Click into the terminal and type; move the pointer off the notch and back within a second: it stays open and typing still goes to the shell. Stay off longer than 1 s: it closes. Hover-only (no click): it still closes after about 0.1 s.
Check 110 worked on ffb8667, but 1 s felt slow; now 0.5 s (Shash, 2026-11-10):
111. **Drift with focus at 0.5 s.** Click into the terminal and type; drift off and back within half a second: it stays open and typing still goes to the shell. Stay off longer: it closes after about 0.5 s. Hover-only: about 0.1 s. Hover alone never gives the terminal the keys; ⌃⌥N does.
Check 111 passed (Shash, 2026-11-10, Release 7d66b5d). Then keys on choosing the Terminal tab, and "Type as soon as the notch opens" (D48):
112. **Tab click and ⌘ number.** Hover-open on another tab, click the Terminal tab: the caret turns solid and typing goes to the shell with no second click; secure input is on (`ioreg -l -w 0 | grep -c SecureInputPID` in Terminal.app is 1 or more). Same with ⌘ and Terminal's number after ⌃⌥N. Leaving closes after about 0.5 s.
113. **Type as soon as the notch opens.** Off (default): a hover-open on the Terminal tab keeps the caret hollow and the keys with the app in front. Turn it on in Settings › Terminal (check the help text): a hover-open on Terminal gives the shell the keys at once; with no session yet, Start Session takes them and no shell starts until you press Return or click. Turn it off again.
Checks 112–113 passed (Shash, 2026-11-10, Release 4f03075); Shash keeps "hover never starts a shell". Merged to main 2026-11-10.
