# TASK: Reverse-engineering analysis + foundation

Rules, commands and constraints are in CLAUDE.md. Follow them throughout.

## Goal
Run a reverse-engineering analysis (REA) of Canopy and Atoll, turn it into a feature matrix and architecture plan for DropNotch, then scaffold the foundation. DropNotch must be original code that Shash owns.

## Phase 1: Analysis (done, 2026-10-24)
Canopy's public pages and Atoll's features were analysed, and the decisions D1–D10 were approved by Shash. Outputs: docs/FEATURE_MATRIX.md, docs/ARCHITECTURE.md, docs/RISKS.md, docs/DECISIONS.md and docs/research/.

## Phase 2: Foundation (in progress; plan approved 2026-10-24)

Decision numbers (D1–D14) refer to docs/DECISIONS.md. Start with the `planner` agent and send its plan to Shash. Steps a and b are verification and project setup; step a ends with a report to Shash, and no module code is built until Shash has read it.

Plan for c–j approved by Shash, 2026-10-24: branches `feat/menu-bar` (c), `feat/notch-panel` (d), `feat/hover-state` (e) and `feat/module-registry` (f), merged in that order; the g tests go in the branch whose logic they test. **After `feat/hover-state` merges, stop** and hand Shash the hover device checks from step i. `feat/module-registry` waits for Shash's report.

**Status (2026-10-25):** c, d and e are on main. The d–e checks passed on a notched Mac on 2026-10-25, after the fixes on `fix/hover-glitch`: the D16 correction, the D18 retune, the D19 canvas and D20. The notch opens centred in about 0.2–0.3 s, every deliberate hover opened it, sweeps didn't, and resting at the top edge kept it open. **Branch 4, `feat/module-registry` (step f; decision D21), is implemented and uncommitted, waiting for Shash's review.** Two D20 device checks are still open; they are listed in step i.

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

## Out of scope for Phase 2
Now Playing real sources, file tray, clipboard, and notes modules (Phase 3). MediaRemote (v0.2). Lock screen (beyond v0.2). Sparkle. Launch at login (Phase 3 Settings).

Clipboard module (Phase 3), first step: re-run probe copies 4–6 (detection call and text reads) under the preview flag (`defaults write com.shashwat.ClipboardProbe EnablePasteboardPrivacyDeveloperPreview -bool yes`), with the probe's main-actor fix (D7b); delete the flag afterwards. See docs/research/clipboard-probe-2026-10-24.md §4.

Phase 3 polish: give the open shape top corners/shoulders where it meets the menu bar, so it reads as one piece with the hardware notch (the square top corners show over the menu bar today).
