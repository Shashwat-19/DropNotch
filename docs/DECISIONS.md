# Decisions

Status: Phase 1 decisions, approved by Shash, 2026-10-24.

Each entry records the decision, the alternatives considered and why the decision was made. New decisions are appended with the next number (D11, D12, and so on). A superseded decision is marked in its Status line ("Superseded by DN") and is never deleted. Items marked "pending" are placeholders that Shash fills in after verification.

Terms for a reader new to Swift or AppKit:
- **AppKit**: Apple's macOS UI framework. It handles windows and system hooks. **SwiftUI** is the newer framework used for the view contents.
- **NSPanel**: an AppKit window type for floating utility windows.
- **Tracking area**: an AppKit region that reports when the mouse enters or leaves it.
- **Distributed notification**: a broadcast message that one app posts and other apps on the same Mac can receive.
- **Apple Events (AppleScript)**: messages one app sends to another, for example "play the next track". macOS asks the user for Automation permission for each target app.
- **Entitlement**: a declared capability in the app's signed metadata, for example permission to send Apple Events.
- **Hardened runtime**: a code-signing mode that blocks common code-injection techniques. Exceptions to it (such as disabling library validation) weaken that protection.
- **Notarisation**: Apple's automated check of a Developer ID-signed app, which lets it open without a Gatekeeper override.
- **App Sandbox**: a macOS mode that restricts what an app can access. It is separate from the hardened runtime.
- **Developer ID**: the signing certificate for apps distributed outside the Mac App Store.
- **XcodeGen**: generates the Xcode project from `project.yml`.
- **exactVersion**: a Swift Package Manager setting that pins one exact package version.
- **changeCount**: a counter on `NSPasteboard` that increases each time the clipboard changes.
- **CGDirectDisplayID**: the number macOS assigns to each connected display.

---

## D1. Licence: MIT

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:** DropNotch is released under the MIT licence.

**Alternatives considered:** GPL-3.0. It would allow reuse of GPL-licensed code from Atoll and Boring Notch.

**Why:** MIT gives the most reuse with the fewest conditions. The clean-room split (only `reference-analyst` reads `./reference/`) already keeps GPL code out of the project, so GPL's copyleft benefit does not apply.

**Consequences / follow-ups:**
- No GPL-licensed code, assets or UI strings may enter the repository.
- Every dependency must be compatible with MIT. Its licence is recorded in its own decision (see D10).
- The `LICENSE` file and copyright line were not in scope for this entry. Check that they match this decision.

---

## D2. Now Playing in the MVP: Apple Music and Spotify

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:**
- The MVP's Now Playing covers Apple Music and Spotify only.
- Track changes arrive through each player's distributed notification. This is event-driven, so there is no polling.
- Playback controls are sent with Apple Events (AppleScript).
- The waveform is decorative. It animates only while something is playing and the view is visible, and it stays static in Low Power Mode.
- Every source sits behind a `NowPlayingSource` protocol, so a MediaRemote-based source can be added in v0.2.
- The `com.apple.security.automation.apple-events` entitlement (needed under the hardened runtime) and the `NSAppleEventsUsageDescription` key are added through `project.yml` in Phase 2.

**Alternatives considered:**
- MediaRemote through `ungive/mediaremote-adapter` now. This covers any app, but depends on a workaround for a private framework.
- A real waveform from a Core Audio process tap. This needs macOS 14.2 or later and an audio-capture permission. The deployment target is 14.0.

**Why:** Apple Music and Spotify cover the main use case through public scripting and notifications. Leaving MediaRemote out of the MVP avoids a private-API dependency whose access Apple has already restricted once (RISKS.md §1.1). The decorative waveform avoids the audio-capture permission and the 14.2 requirement.

**Consequences / follow-ups:**
- Verification results: see D2a.
- The adapter's licence and its real security impact are being verified before Phase 2. The adapter loads into `/usr/bin/perl`, not into DropNotch's own process, which is part of that check.
- The notification names are undocumented, so a player update can break event delivery. Test on each macOS release (RISKS.md §4).
- Each player needs its own Automation permission (RISKS.md §2).
- The apple-events entitlement is read against the hardened-runtime rule in D4.

---

## D3. Lock-screen features deferred beyond v0.2

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:** These are not planned for the MVP or v0.2:
- full-screen now playing on the lock screen
- Mac battery on the lock screen
- audio-device battery on the lock screen
- air quality (AQI) on the lock screen
- outdoor temperature on the lock screen

"Temperature" means outdoor temperature.

**Alternatives considered:** As presented to Shash in the Phase 1 decision list (RISKS.md §1.3):
- a private window-server Space (the SkyLightWindow route)
- rewriting the wallpaper store and stopping wallpaper processes

**Why:** No public API draws over the lock screen. Both known routes are private and high-risk. The Space route depends on a private package pinned to a branch. The wallpaper route can damage the user's wallpaper settings if the backup or restore fails.

**Consequences / follow-ups:**
- Any later lock-screen work needs a new decision. It would sit behind a protocol in `Services/`, be opt-in, and be reviewed by `security-auditor` and `dependency-manager`.
- The wallpaper route is ruled out.
- Lock-state detection is not part of this decision. The MVP pauses the clipboard poll on screen sleep only; lock detection is checked in Phase 2 (D7).

---

## D4. No App Sandbox; hardened runtime on; no exceptions in the MVP

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:**
- DropNotch is not sandboxed.
- The hardened runtime is on.
- The MVP adds no hardened-runtime exceptions, such as `com.apple.security.cs.disable-library-validation`.

**Alternatives considered:** App Sandbox, with the entitlements and file-access exceptions it would need.

**Why:** Private APIs and Apple Events to other apps are impractical inside the sandbox. DropNotch is not on the Mac App Store, so the sandbox brings no distribution benefit. The hardened runtime is needed for notarisation.

**Consequences / follow-ups:**
- Without the sandbox a bug has a wider reach. `security-auditor` reviews every change to the file tray, clipboard, subprocesses or entitlements.
- The apple-events entitlement from D2 is a hardened-runtime *resource-access* entitlement (it lets the app ask the user for Automation permission), not a *runtime exception* that weakens code-signing protection [I: Apple lists it under hardened runtime resource access; confirm against developer.apple.com in Phase 2 step a].

---

## D5. Closed notch panel sized to the notch; pill on non-notch screens

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:** While closed, the panel is sized to exactly the notch rectangle and accepts mouse events, so a tracking area can detect hover. On a screen without a notch, the closed state is a pill at the top centre. The area outside the notch rectangle is click-through because no window covers it.

**Alternatives considered:** A full-width click-through panel (`ignoresMouseEvents = true`) plus a global mouse-moved monitor.

**Why:** A click-through window receives no mouse events, so hover cannot be detected from it. The only alternative is a system-wide mouse-moved monitor, which fires on every mouse movement and costs energy. ARCHITECTURE.md §9 forbids idle wake-ups.

**Consequences / follow-ups:**
- This supersedes the TASK.md wording "click-through when closed". The end result for clicks outside the notch is the same, but the mechanism is a smaller window, not a flag.
- TASK.md and ARCHITECTURE.md §6 were updated to match D5.
- Hover at the top pixel row is unproven. Check it on a real notched Mac first in Phase 2 (RISKS.md §4).

---

## D6. File tray: bookmark first, copy as fallback

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:**
- Each tray item stores a bookmark to the original file first. A bookmark is macOS's reference to a file, which can follow the file if it is renamed or moved. Whether it does so in each case is to be checked against Apple's documentation in Phase 2.
- If there is no file behind the drop, or access is denied, the file is copied into app storage instead.
- An item whose original is missing is shown greyed out.

**Alternatives considered:** Always copy into app storage.

**Why:** Copying every file duplicates data, uses disk space and can leave stale copies. A bookmark keeps the original as the single source. The copy fallback covers drops with no file path, such as an image dragged from a web page, and protected folders where access is denied.

**Consequences / follow-ups:**
- A moved or deleted original breaks the item. The tray keeps the item visible but greyed out.
- Copied items do not update when the original changes.
- macOS folder prompts (Desktop, Documents, Downloads) may appear on first access (RISKS.md §2).
- Copies are stored under Application Support (ARCHITECTURE.md §5).
- `security-auditor` reviews the file tray before merge.

---

## D7. Clipboard history rules

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:**
- Poll `NSPasteboard.general.changeCount` every 0.5 s, with a 0.25 s tolerance.
- Pause the poll while the screens are asleep. Pausing on lock waits for the Phase 2 check, since there is no documented lock notification [I].
- Skip any item whose types include the concealed, transient or auto-generated markers (`org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, `org.nspasteboard.AutoGeneratedType`).
- Keep history in memory by default. Saving to disk is opt-in.
- Keep 25 items.
- Never log clipboard content.

**Alternatives considered:** As presented in the Phase 1 decision list. The behaviour rejected (ARCHITECTURE.md §5) is Atoll's: persistence on by default, with clipboard text kept in `UserDefaults`, and no skipping of concealed types.

**Why:** macOS has no public notification for pasteboard changes, so polling the integer `changeCount` is the cheapest reliable check. Skipping concealed items keeps passwords from entering history. Memory-only storage keeps copied text out of preference files by default. The 25-item cap bounds memory use.

**Consequences / follow-ups:**
- Phase 2 first tests the macOS clipboard-access warning on the current macOS and reports to Shash before the module is built.
- The marker names follow the nspasteboard.org convention. This is to be confirmed (ARCHITECTURE.md §8).
- This poll is the only always-on timer in the MVP (ARCHITECTURE.md §9).

---

## D8. Customisable layout as fixed slots

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:** Layout customisation is limited to fixed slots:
- which module fills the compact-left slot
- which module fills the compact-right slot
- the order of the expanded tabs

**Alternatives considered:** A free-form drag layout, where modules can be placed anywhere.

**Why:** The notch area is small, and fixed slots fit it without a layout engine. Fewer layout states are easier to test. Customisation is secondary to productivity (CLAUDE.md), so a fuller editor is not justified yet.

**Consequences / follow-ups:**
- Settings needs only slot pickers and a tab-order control (ARCHITECTURE.md §2).
- A free-form layout would need a new decision.
- `accessibility-auditor` reviews the settings UI.

---

## D9. One display in the MVP

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:** The MVP shows one panel. It sits on the built-in display if that display has a notch, and otherwise on the main display. Displays are identified by `CGDirectDisplayID`, never by localised name.

**Alternatives considered:** As presented in the Phase 1 decision list. The option in FEATURE_MATRIX.md (the Notch on several displays row) is one panel per display from the start, as Atoll does.

**Why:** One panel means fewer windows and fewer screen-change paths to test. Names are unreliable for identical monitors, so IDs are used instead (ARCHITECTURE.md §7).

**Consequences / follow-ups:**
- All-displays mode is v0.2. It needs its own decision on per-display layout.
- Screen-change handling (a 0.2 s debounce after `didChangeScreenParametersNotification`) is described in ARCHITECTURE.md §7.

---

## D10. Dependencies and distribution

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Decision:**
- Add `sindresorhus/KeyboardShortcuts` for the global hotkey. Pin it with `exactVersion` in `project.yml`.
- Licence and version: see D10a.
- No Sparkle yet.
- Until there is a Developer ID, publish only pre-release developer builds on GitHub, labelled as such.
- Public 1.0 waits for signing and notarisation.

**Alternatives considered:**
- Call the Carbon hot-key API directly, with no dependency (FEATURE_MATRIX.md, Hotkey row).
- Add Sparkle in the MVP (RISKS.md §3). Rejected because updates need a Developer ID and an EdDSA key first.
- Release publicly before there is a Developer ID. Rejected because Gatekeeper blocks unsigned apps on first launch (RISKS.md §3).

**Why:** A wrapper saves writing and maintaining our own hot-key code. The exact pin keeps the version fixed. `Package.resolved` lives inside the gitignored `.xcodeproj`, so the pin in `project.yml` is the only record of the version. Pre-release builds let testers try the app without a signing certificate.

**Consequences / follow-ups:**
- Licence and version are recorded in D10a; the licence is MIT-compatible (D1).
- Sparkle needs its own decision and licence entry when adopted in v0.2. The EdDSA private key stays out of the repository.
- The README install section must give the Gatekeeper override steps for pre-release builds (RISKS.md §3).

## D10a. KeyboardShortcuts: licence and version

**Date:** 2026-10-24 · **Status:** Accepted (verification for D10)

- Licence: MIT, copyright Sindre Sorhus [V: https://github.com/sindresorhus/KeyboardShortcuts/blob/main/license]. Compatible with MIT DropNotch (D1) [I: both permissive; MIT only requires keeping the notice].
- Pin: `exactVersion: 3.1.0`, released 2026-09-11, latest stable; release notes mention macOS 27 compatibility [V: https://github.com/sindresorhus/KeyboardShortcuts/releases/tag/3.1.0].
- 3.0.0 was a breaking release that renamed the default-shortcut API and moved the package to Swift 6 [V: https://github.com/sindresorhus/KeyboardShortcuts/releases/tag/3.0.0]. DropNotch stays in Swift 5 language mode. Swift packages compile in their own language mode, so this should not affect the app [I: confirm when the Phase 2 build runs].
- Requires macOS 10.15+, no dependencies of its own [V: README and Package.swift]. Package manifest needs swift-tools 6.2, which Xcode 27.1 is expected to satisfy [I].
- It uses Carbon's global hot-key API, which is public but legacy. Apple has no newer replacement [V: README FAQ for the Carbon use; I for "no replacement"].
- Ship its licence text in a third-party notices file in the app bundle.

## D2a. MediaRemote adapter: licence and security check (verification for D2)

**Date:** 2026-10-24 · **Status:** Accepted (verification for D2; no adapter code is added until v0.2)

- **Licence:** ungive/mediaremote-adapter is BSD-3-Clause, copyright Jonas van den Berg and contributors. The Perl script carries the same notice [V: https://github.com/ungive/mediaremote-adapter/blob/master/LICENSE and the script header]. It is compatible with MIT DropNotch; the notice must ship with the app [I: standard BSD-3 terms]. The latest release seen is v0.7.7 (2026-09-03) [V: GitHub releases]. The README warns the API may break across minor versions [V].
- **Why Perl:** the README says MediaRemote stopped working when loaded inside apps from macOS 15.4, and that processes reporting an Apple bundle ID are allowed; `/usr/bin/perl` reports `com.apple.perl` [V: upstream README]. Why that bypass works is Apple-internal and undocumented [I].
- **Security settings:** DropNotch needs no hardened-runtime exception for this design. The framework is loaded by `/usr/bin/perl`, which has no hardened runtime or entitlements, and our own process never loads it [V: README integration notes; `codesign` on /usr/bin/perl; security-auditor local test on macOS 27.0.1 with a dummy library]. The earlier wording, "weakens the hardened runtime", described Atoll's entitlement, not our design, and has been corrected in RISKS.md and FEATURE_MATRIX.md.
- **Alternatives considered:** load the framework in-process (needs disable-library-validation, which draws extra Gatekeeper checks and widens code-injection risk); no generic now playing at all.
- **Conditions for v0.2:** build the framework from upstream source at a pinned commit; sign it with our Developer ID; check the bundle signature before launching Perl; minimal environment, fixed argument arrays; run the adapter's own `test` command at most once per macOS build; stream without artwork; never log the output; `dependency-manager` and `security-auditor` review before merge.
- **Not verified:** the real adapter wasn't run, and no Developer-ID-signed framework or notarisation was tested.

