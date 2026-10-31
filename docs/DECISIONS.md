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
- Playback controls are sent with Apple Events (AppleScript). Refined by D22: raw Apple Events to the running app's pid, not AppleScript.
- The waveform is decorative. It animates only while something is playing and the view is visible, and it stays static in Low Power Mode.
- Every source sits behind a `NowPlayingSource` protocol, so a MediaRemote-based source can be added in v0.2.
- The `com.apple.security.automation.apple-events` entitlement (needed under the hardened runtime to send Apple Events to other apps such as Music and Spotify; not needed for same-team processes [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events]) and the `NSAppleEventsUsageDescription` key are added through `project.yml` in Phase 2.
- The usage text ("DropNotch sends play, pause and skip commands to Music and Spotify…") describes commands that don't exist yet. Re-check it whenever the Now Playing feature changes. (2026-10-25: the commands exist, and the text now also covers reading the current track; D23.)

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

**Why:** Private APIs and Apple Events to other apps are impractical inside the sandbox. DropNotch is not on the Mac App Store, so the sandbox brings no distribution benefit. The hardened runtime is needed for notarisation [V: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution].

**Consequences / follow-ups:**
- Without the sandbox a bug has a wider reach. `security-auditor` reviews every change to the file tray, clipboard, subprocesses or entitlements.
- The apple-events entitlement from D2 is a hardened-runtime *resource-access* entitlement (it lets the app ask the user for Automation permission), not a *runtime exception* that weakens code-signing protection [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events; https://developer.apple.com/documentation/security/hardened-runtime lists it under Resource Access, not Runtime Exceptions]. It is not needed for targets signed by the same team ID.

---

## D5. Closed notch panel sized to the notch; pill on non-notch screens

**Date:** 2026-10-24
**Status:** Accepted (approved by Shash)

**Revised by D28** (2026-10-31): while music plays, the closed shape is wider than the notch.

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
- Pause the poll while the screens are asleep [V: https://developer.apple.com/documentation/appkit/nsworkspace/screensdidsleepnotification]. Pausing on lock waits for the Phase 2 check, since no lock notification is documented [I].
- Skip any item whose types include the concealed, transient or auto-generated markers (`org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, `org.nspasteboard.AutoGeneratedType`).
- Keep history in memory by default. Saving to disk is opt-in.
- Keep 25 items.
- Never log clipboard content.

**Alternatives considered:** As presented in the Phase 1 decision list. The behaviour rejected (ARCHITECTURE.md §5) is Atoll's: persistence on by default, with clipboard text kept in `UserDefaults`, and no skipping of concealed types.

**Why:** macOS has no public notification for pasteboard changes, so polling the integer `changeCount` is the cheapest reliable check. Skipping concealed items keeps passwords from entering history. Memory-only storage keeps copied text out of preference files by default. The 25-item cap bounds memory use.

**Consequences / follow-ups:**
- Phase 2 step a probe, 2026-10-24 (docs/research/clipboard-probe-2026-10-24.md): on macOS 27.0.1 an ad-hoc background app reported `accessBehavior` = `alwaysAllow`, read the change counter, types and text with no alert [V]. Behaviour under "ask" (Apple's documented default) is still untested. Shash approved the design changes as D7a.
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

**Why:** One panel means fewer windows and fewer screen-change paths to test. Names are unreliable for identical monitors, so IDs are used instead (ARCHITECTURE.md §7). A display ID can persist across processes and typically stays constant until the machine restarts [V: https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid]. After a restart the saved ID may not match, so the saved choice falls back to the built-in display when no match is found.

**Consequences / follow-ups:**
- All-displays mode is v0.2. It needs its own decision on per-display layout.
- Screen-change handling (a 0.2 s debounce after `didChangeScreenParametersNotification`) is described in ARCHITECTURE.md §7.
- Implemented in Phase 2 through D17: the first screen with a notch, otherwise the menu-bar screen. There is no saved choice yet.

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
- 3.0.0 was a breaking release that renamed the default-shortcut API and moved the package to Swift 6 [V: https://github.com/sindresorhus/KeyboardShortcuts/releases/tag/3.0.0]. DropNotch stays in Swift 5 mode: the package module compiles with `-swift-version 6` and the app module with `-swift-version 5`, and build and tests pass [V: local build logs, 2026-10-24].
- Requires macOS 10.15+. No package-level dependencies, so nothing transitive is fetched [V: Package.swift; Package.resolved has one pin]. Manifest needs swift-tools 6.2, satisfied by the installed Swift 6.4 toolchain [V: `swift --version`].
- Resolved to revision `772133d9dbe800fdac0473226822994c5c162c58` (tag 3.1.0); the checked-out `license` file is MIT [V: Package.resolved, checkout]. Verified by `dependency-manager` on 2026-10-24 after the package was added on feat/project-config.
- It uses Carbon's global hot-key API, which is public but legacy. That Apple has no newer replacement is unverified: current Apple docs list the Carbon hot-key API only in the archive [I].
- Ship its licence text in the app bundle: added as THIRD_PARTY_NOTICES.md (commit 84b16fd), the verbatim MIT text from the 3.1.0 checkout, bundled as a resource [V: Release build Resources folder, 2026-10-24].

## D2a. MediaRemote adapter: licence and security check (verification for D2)

**Date:** 2026-10-24 · **Status:** Accepted (verification for D2; no adapter code is added until v0.2)

- **Licence:** ungive/mediaremote-adapter is BSD-3-Clause, copyright Jonas van den Berg and contributors. The Perl script carries the same notice [V: https://github.com/ungive/mediaremote-adapter/blob/master/LICENSE and the script header]. It is compatible with MIT DropNotch; the notice must ship with the app [I: standard BSD-3 terms]. The latest release seen is v0.7.7 (2026-09-03) [V: GitHub releases]. The README warns the API may break across minor versions [V].
- **Why Perl:** the README says MediaRemote stopped working when loaded inside apps from macOS 15.4, and that processes reporting an Apple bundle ID are allowed; `/usr/bin/perl` reports `com.apple.perl` [V: upstream README]. Why that bypass works is Apple-internal and undocumented [I].
- **Security settings:** DropNotch needs no hardened-runtime exception for this design. The framework is loaded by `/usr/bin/perl`, which has no hardened runtime or entitlements, and our own process never loads it [V: README integration notes; `codesign` on /usr/bin/perl; security-auditor local test on macOS 27.0.1 with a dummy library]. The earlier wording, "weakens the hardened runtime", described Atoll's entitlement, not our design, and has been corrected in RISKS.md and FEATURE_MATRIX.md.
- **Alternatives considered:** load the framework in-process (needs disable-library-validation, which draws extra Gatekeeper checks and widens code-injection risk); no generic now playing at all.
- **Conditions for v0.2:** build the framework from upstream source at a pinned commit; sign it with our Developer ID; check the bundle signature before launching Perl; minimal environment, fixed argument arrays; run the adapter's own `test` command at most once per macOS build; stream without artwork; never log the output; `dependency-manager` and `security-auditor` review before merge.
- **Not verified:** the real adapter wasn't run, and no Developer-ID-signed framework or notarisation was tested.

---

## D11. Hardened runtime applies to Release builds only until a Developer ID exists.

**Date:** 2026-10-24
**Status:** Accepted

**Decision:**
- `project.yml` keeps `ENABLE_HARDENED_RUNTIME: YES`. Xcode leaves the runtime off for ad-hoc ("Sign to Run Locally") Debug builds and applies it to Release.
- Until a Developer ID exists, the hardened runtime is therefore a Release-only property. This refines D4's "the hardened runtime is on" for local Debug builds.

**Evidence** [V: local builds 2026-10-24, macOS 27.0.1, Xcode 27.1]:
- Debug app: `codesign` flags=0x2(adhoc).
- Release app: flags=0x10002(adhoc,runtime).
- Forcing `--options=runtime` on the Debug app made it fail to load its own debug dylib with "mapping process and mapped file (non-platform) have different Team IDs". The test runner crashed.

**Alternatives considered:**
- Force the runtime in Debug and disable library validation. Rejected: this is a hardened-runtime exception, against D4.
- Turn off the debug-dylib split (`ENABLE_DEBUG_DYLIB: NO`) and force the runtime. Not chosen for now: the app then builds and launches hardened [V: security-auditor local build, 2026-10-24], but whether the injected test bundle passes library validation is untested [I], and SwiftUI Previews may reload more slowly. Shash decided (2026-10-24) to keep Debug as it is.

**Why:** Library validation accepts only code signed by Apple or with the same Team ID as the main executable [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation]; an ad-hoc signature has no Team ID [V: codesign shows TeamIdentifier=not set], so the app can't be matched against its own debug dylib. Once a Developer ID exists, Debug can be revisited.

**Consequences / follow-ups:**
- Rule added to CLAUDE.md (Shash, 2026-10-24): any change touching entitlements, Apple Events or signing must also pass a Release build and a Release launch before merging.
- Anything that must be tested under the hardened runtime, such as the Apple Events Automation prompts in Phase 2, is tested with a Release build.
- Revisit when a Developer ID exists.
- README.md and docs/ARCHITECTURE.md were checked: neither describes the hardened runtime as on for every build [V: code-reviewer, 2026-10-24].

---

## D12. Docs appear in Xcode's navigator as reference-only files.

**Date:** 2026-10-24
**Status:** Accepted (requested by Shash)

**Decision:** `project.yml` `fileGroups` lists `CLAUDE.md`, `TASK.md` and `docs`, so they show in Xcode's navigator with no target membership. They are not copied into the app.

**Evidence** [V: local build 2026-10-24]: the generated project has file references for them and no build-file entries, and the built app contains no `.md` files.

**Alternatives considered:** Leave them out of the project. Rejected: Shash wants them visible while working in Xcode.

**Why:** The files stay one click away while working in Xcode, and they are not bundled into the app.

**Consequences / follow-ups:**
- The `fileGroups` comment in `project.yml` describes this decision. Keep the two in step.
- After any change to `fileGroups`, check that the built app still contains no `.md` files.

---

## D13. Release builds don't carry the debugger entitlement

**Date:** 2026-10-24 · **Status:** Accepted (security-auditor finding on feat/project-config)

**Decision:** set `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` for the DropNotch target's Release configuration in `project.yml`. Debug keeps Xcode's injected entitlements so the debugger can attach.

**Evidence:** before the change, the ad-hoc Release app carried `com.apple.security.get-task-allow`; after it, only `com.apple.security.automation.apple-events`, still with the hardened-runtime flag [V: `codesign -d --entitlements -` and `codesign -dvvv` on local Release builds, 2026-10-24]. Debug build and tests still pass [V: local build].

**Alternatives considered:** leave it to the Developer ID export step to strip the entitlement (rejected: cheap to fix now, and the export path isn't verified to strip it).

**Why:** `get-task-allow` lets other processes running as the same user attach to the app and read its memory [I: no Apple page checked for this; confirm], which would include clipboard history. Notarisation requires it not to be set to true [V: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution].

**Consequences / follow-ups:** the release pipeline (cicd-agent) should check the shipped app's entitlements with `codesign` before notarising.



## D7a. Clipboard history handles macOS pasteboard privacy

**Date:** 2026-10-24 · **Status:** Accepted (approved by Shash; refines D7)

**Decision:** clipboard history stays in the MVP, with three changes to D7:
1. When the user turns clipboard history on, check `NSPasteboard.general.accessBehavior` (macOS 15.4+, behind `#available`; the deployment target is 14.0). `alwaysAllow`: start watching. `ask` or `default`: show DropNotch's own explanation first, then start. `alwaysDeny`: don't start; show a "blocked in System Settings" state instead of an empty history.
2. Read in the cheapest order: `changeCount` on the timer, `types` only when it changes, skip concealed and transient items, and only then read the content.
3. Re-check `accessBehavior` on each content read and stop watching if it becomes `alwaysDeny`, because denied access fails silently [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum].

**Evidence:** step a probe on macOS 27.0.1: `alwaysAllow`, all reads succeeded, no alert [V: docs/research/clipboard-probe-2026-10-24.md]. Apple says the default is "to ask upon programmatic access" from macOS 15.4 [V: same URL].

**Alternatives considered:** move clipboard history to v0.2 (rejected: reads worked under `alwaysAllow`, and the design above handles ask and deny); rely on the observed `alwaysAllow` (rejected: it contradicts Apple's documented default and may differ on other Macs).

**Consequences / follow-ups:** under the preview flag, `changeCount` and `types` reads gave no alert; detection and text reads are untested and are re-run as the first step of the Clipboard module (report §4).

## D7b. Pasteboard calls run on the main thread

**Date:** 2026-10-24 · **Status:** Accepted (Shash)

**Decision:** every `NSPasteboard` call (reads, `accessBehavior`, `detectedPatterns(for:)`) runs on the main actor. Async calls are awaited from `@MainActor` code, never from a detached or background `Task`.

**Evidence:** under the pasteboard privacy preview (`accessBehavior` = `default`), the probe called `detectedPatterns(for:)` from a background `Task` and AppKit threw `NSInternalInconsistencyException`: "-[HIRunLoopSemaphore wait:] has been invoked on a secondary thread" [V: probe stderr, 2026-10-24; docs/research/clipboard-probe-2026-10-24.md §4]. Under `alwaysAllow` the same call didn't crash, so the bug only shows under the privacy setting.

**Why:** a crash that appears only when the user's privacy setting changes would be hard to catch in testing. Keeping the pasteboard on the main actor also matches CLAUDE.md (UI state on `@MainActor`). `PasteboardWatcher` (ARCHITECTURE.md §8) is main-actor isolated.

**Consequences:** the 0.5 s poll and reads stay on the main thread. They are cheap, so this shouldn't break the "nothing blocking on the main thread" rule [I: to measure in the Clipboard module].

## D14. Menu-bar item uses SwiftUI `MenuBarExtra`

**Date:** 2026-10-24 · **Status:** Accepted (Shash, Phase 2 plan)

**Decision:** the menu-bar item is a SwiftUI `MenuBarExtra` (menu style) with Settings… (⌘,) and Quit (⌘Q), plus a SwiftUI `Settings` scene. Settings… calls `NSApp.activate()` and then `openSettings()`. Launch at login moved to Phase 3 Settings (Shash, 2026-10-24).

**Evidence:** `MenuBarExtra` is macOS 13+ [V: https://developer.apple.com/documentation/swiftui/menubarextra]; `OpenSettingsAction` is macOS 14+ and is read from a view's environment [V: https://developer.apple.com/documentation/swiftui/opensettingsaction]; `NSApplication.activate()` is macOS 14+ and "activates the receiver app, if appropriate" [V: https://developer.apple.com/documentation/appkit/nsapplication/activate()].

**Alternatives considered:** `NSStatusItem` with an `NSMenu`, as TASK.md first said (rejected: more AppKit code, and opening SwiftUI's `Settings` scene from AppKit has no public API [I], while `openSettings` works from a SwiftUI menu).

**Why:** for a Swift newcomer, the menu is a few lines of SwiftUI. The `activate()` call is there because opening a menu-bar menu doesn't make an agent app (`LSUIElement`) active, so its Settings window could otherwise open behind the frontmost app [I: device check]. `openSettings` is only available inside a `View`, which is why the menu items live in a separate `MenuBarMenu` view rather than in the `App` body.

**Consequences / follow-ups:** device check: Settings comes to the front and takes keyboard focus. If not, the fallback is switching the activation policy to `.regular` while Settings is open (FEATURE_MATRIX, "Menu-bar item with Settings and Quit" row).

## D15. Reserved

Withdrawn before use: it was planned for launch at login, which moved to Phase 3 (D14).

## D16. AppKit owns the notch window; SwiftUI draws inside it

**Date:** 2026-10-24 · **Status:** Accepted (Phase 2 plan, step d)

**Decision:** the SwiftUI `App` uses `@NSApplicationDelegateAdaptor` to create an `AppDelegate`, which creates `NotchPanel` (an `NSPanel` subclass) and puts a SwiftUI `NotchRootView` inside it through `NotchHostingView` (an `NSHostingView` subclass). Panel settings:
- borderless and `.nonactivatingPanel`, so clicking it doesn't activate DropNotch
- clear background, no shadow, not movable, `hidesOnDeactivate = false`
- level `.statusBar`
- joins all Spaces, works over full-screen apps, stationary, left out of window cycling
- `canBecomeKey` and `canBecomeMain` return false
- shown with `orderFrontRegardless()`

`NotchHostingView` sets `sizingOptions = []` and sits inside a plain `NSView` container that is the panel's `contentView`; the hosting view keeps a fixed screen rect (D19). The root view ignores the safe area.

**Correction (2026-10-24, fix/hover-glitch):** the first version made the hosting view itself the `contentView`, on the belief that `sizingOptions = []` stops SwiftUI resizing the window. It doesn't. The docs say `[]` creates no constraints, but a hosting view that is a window's `contentView` also updates the window's `contentMinSize` and `contentMaxSize`, and nothing says `[]` turns that off. On the device the window snapped back to the shape's size straight after each `setFrame`, followed the spring frame by frame, and the app crashed in an Update Constraints pass (crash stack: `NSHostingView.updateWindowContentSizeExtremaIfNecessary` → `setNeedsUpdateConstraints`). The container takes the hosting view out of that role.

**Evidence:**
- `hidesOnDeactivate` defaults to true for `NSPanel` [V: https://developer.apple.com/documentation/appkit/nswindow/hidesondeactivate]. An agent app is almost never active, so it would hide straight away.
- `orderFrontRegardless()` "moves the window to the front of its level, even if its application isn't active, without changing either the key window or the main window" [V: https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless()].
- `sizingOptions` defaults to `.standardBounds`, and when the hosting view is a window's content view it also updates the window's min and max content size [V: https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions].
- `.fullScreenAuxiliary` shows the window on the same Space as a full-screen window [V: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary]. `.stationary` keeps it unaffected by Mission Control [V: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/stationary].
- `.statusBar` is Apple's "level for a status window" [V: https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/statusbar]. That it sits above the menu bar and above full-screen apps is [I: device check].

**Alternatives considered:**
- A SwiftUI `Window` scene. Rejected: SwiftUI has no public control over non-activating behaviour, window level or Spaces behaviour.
- Atoll's level, `mainMenu + 3`. Not chosen: a named level is easier to reason about. It can be raised if the device check fails.

**Why (for a Swift newcomer):**
- SwiftUI is good at drawing, but the notch needs window behaviour that only AppKit exposes.
- `sizingOptions = []` stops SwiftUI adding size constraints, and the container stops it resizing the window, so only `NotchGeometry` sets the frame.
- A fixed open-size panel with click-through was considered instead and rejected: reliable click-through needs `ignoresMouseEvents`, which also silences the tracking area, so it would need a global mouse-moved monitor (against D5 and D18).
- `.ignoresSafeArea()` matters because the panel sits over the camera housing. SwiftUI would otherwise push the content down out of the safe area [I: device check].
- ARCHITECTURE §6's `acceptsFirstMouse` override isn't added yet, because Phase 2 has no clickable controls. (Added 2026-10-25 with the Now Playing controls, `NotchHostingView`.)

## D17. The notch display is chosen from `NSScreen.screens` and kept by display ID

**Date:** 2026-10-24 · **Status:** Accepted (Phase 2 plan, step d; refines the planner's CGDisplay calls)

**Decision:** the pure `ScreenObserver.chooseDisplay` picks the first screen that has a notch. If no screen has one, it picks `NSScreen.screens[0]`. Screens are identified by the `CGDirectDisplayID` stored under the `NSScreenNumber` key of `deviceDescription`.

**Evidence:**
- The screen at index 0 of `NSScreen.screens` is "the screen that contains the menu bar and whose origin is at the point (0, 0)" [V: https://developer.apple.com/documentation/appkit/nsscreen/screens].
- With mirroring, `screens[0]` is the largest drawable display instead [V: same page].
- `NSScreen.main` is the screen with the key window, not the menu-bar screen [V: https://developer.apple.com/documentation/appkit/nsscreen/main].
- `NSScreenNumber` holds the display ID as an `NSNumber` [V: https://developer.apple.com/documentation/appkit/nsscreen/devicedescription].
- The auxiliary top areas are in global screen coordinates and are nil when the top of the screen isn't obscured [V: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc].

**Alternatives considered:**
- `CGDisplayIsBuiltin` plus `CGMainDisplayID()`, as the planner proposed. Dropped: both are extra calls with no effect on the result. Only a built-in panel has a camera housing [I], and `screens[0]` is already documented as the menu-bar screen.
- Matching screens by name. Rejected: two identical monitors share a name.

**Why:** keeping the choice a pure function over `(id, hasNotch)` pairs makes D9 testable without real displays.

## D18. Hover uses an AppKit tracking area and a pure state machine

**Date:** 2026-10-24 · **Status:** Accepted (Phase 2 plan, step e)

**Decision:**
- `NotchHostingView` adds one `NSTrackingArea` with `.mouseEnteredAndExited`, `.activeAlways` and `.inVisibleRect`. Its enter and exit events go to `NotchState.send(_:)`.
- `NotchHoverStateMachine` is a value type. Its `handle(_:)` returns an effect: start or cancel the open delay, or start or cancel the exit debounce. `NotchState` runs each kind with its own cancellable `Task.sleep`, and starting a timer replaces a running one of the same kind.
- Peek is the phase between the pointer entering and the open delay ending. The shape grows by `NotchGeometry.peekGrowth` (decision 2 of the Phase 2 plan, Shash).
- A brief exit during peek doesn't restart the open delay. The delay keeps running through the exit debounce. If it ends while the pointer is outside, the notch opens as soon as the pointer comes back within the debounce, and stays closed if it doesn't.

**Retuned 2026-10-25 (fix/hover-glitch, Shash):** device recordings showed hover → open taking about 0.6 s, and most peeks closing without opening.
- Open delay: 0.3 s → 0.12 s.
- Peek growth: (16, 4) → (24, 8) pt, so 12 pt each side and 8 pt down, a bigger target to stay inside.
- The open delay now survives a brief exit (above). It used to share one timer with the exit debounce, so an exit cancelled it.
- That run's log rejected pointer jitter as the cause: there were no re-entries during peek, so the change to the open delay would have saved none of the 32 failed peeks. 15 left downwards within 0.3 s, which the bigger peek helps with.
- The other 17 exited at exactly the screen's top edge (y = maxY): a pointer pushed against the top of the screen reports y = maxY, which is outside the panel frame. Neither change fixes that. A fix that extends the panel 1 pt above the screen is proposed and awaiting approval [I: device check].

**Evidence:**
- `.activeAlways` delivers events "regardless of first-responder status, window status, or application status" [V: https://developer.apple.com/documentation/appkit/nstrackingarea/options-swift.struct/activealways].
- With `.inVisibleRect` the area "is automatically synchronized with changes in the view's visible area" [V: https://developer.apple.com/documentation/appkit/nstrackingarea/options-swift.struct/invisiblerect].
- Whether the area fires at the top pixel row is [I: device check, RISKS §4].

**Alternatives considered:**
- SwiftUI `onHover`. Rejected: it gives no control over when the area is active, and DropNotch is never the active app.
- A global mouse-moved monitor. Rejected under D5.
- `handle(_:) -> State`, as the ARCHITECTURE §4 sketch had it. Changed: with effects, the timer logic is decided in the pure, tested code, and `NotchState` only carries it out.

**Why (for a Swift newcomer):**
- `NSHostingView` also receives `mouseEntered`/`mouseExited` for SwiftUI's own tracking areas. The overrides therefore call `super` and only forward events whose `trackingArea` is ours.
- A cancelled timer never delivers its event: the timer `Task` and `cancel()` both run on the main actor, and the task checks `Task.isCancelled` after sleeping. As a second line of defence, the state machine ignores events that don't fit the current phase (for example, an open-delay event after the pointer left).

## D19. Grow the panel before animating, shrink it after

**Date:** 2026-10-24 · **Status:** Accepted (Phase 2 plan, step e)

**Decision:**
- When the notch grows (to peek or open), `NotchState` sets the panel to the larger frame first, then animates the shape with a spring (0.25 s, no bounce; was 0.35 s with bounce 0.15 until 2026-10-25, which felt slow, and its overshoot was cut flat by the panel's edges).
- When it closes, the shape animates first. The `withAnimation` completion then shrinks the panel to the current geometry's closed frame. It does this only if nothing has changed since the close started: no phase change and no screen change, tracked by a counter.
- When it grows while the panel is already larger than the target (re-entering during a close), the panel keeps its larger frame.
- With Reduce Motion on, the animation is `nil`, so the change is immediate.
- The hosting view (the canvas) stays at the open frame's screen rect. `NotchPanel.setFrame(_:canvas:)` repositions it inside the panel with every panel frame change (open origin minus panel origin, so it stays on whole pixels), and the container clips it to the panel (added 2026-10-24, fix/hover-glitch).

**Evidence:**
- Device recording before the canvas change: when the panel grew, the shape's left edge jumped to the new panel's left edge and only the right edge animated. The hosting view's new size reached SwiftUI in the same update as the animated phase change, so the shape's position animated from where it sat in the old, smaller layout. With a fixed-size canvas there is no re-layout, so only the shape's size animates.
- The `withAnimation(_:completionCriteria:_:completion:)` completion "will always be fired exactly one time", and right away when no animation runs [V: https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)]. This is macOS 14+, which matches the deployment target.
- The Reduce Motion setting is read from `NSWorkspace.accessibilityDisplayShouldReduceMotion` [V: https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion].

**Alternatives considered:**
- Animate the window frame itself with AppKit. Rejected: two animation systems would run against each other, and resizing a window every frame costs more than redrawing a shape.
- Keep the panel at the open size all the time. Rejected under D5: it would block clicks around the notch.

**Why:**
- The shape can only draw inside the panel. So the panel has to be big enough before the shape grows, and it can't shrink until the shape has finished shrinking.
- The counter matters because the pointer can come back, or a display can be unplugged, during the close animation. Without it, an old completion would shrink the panel at the wrong moment or move it back to the old screen's frame (code-reviewer W1).

**Trade-off:** for about 0.25 s after closing starts, the panel's larger, mostly transparent frame may still catch clicks and hover [I: device check; whether macOS passes clicks through fully transparent pixels is not documented]. Re-entering in that time peeks and then reopens the notch.

## D20. The panel reaches 1 pt above the screen, and fast sideways moves restart the open delay

**Date:** 2026-10-25 · **Status:** Accepted (fix/hover-glitch, Shash). Branch 4's registry decision moves to D21.

**Decision:**
- **Top edge.** Every panel frame is `NotchGeometry.panelFrame(for:)`: the shape's frame plus `topOverhang` (1 pt) above the screen's top edge. The shape still uses `frame(for:)`, and `NotchRootView` pads its top by the same 1 pt, so nothing visible moves. `NotchPanel` overrides `constrainFrameRect(_:to:)` to return the frame unchanged. The tracking area covers the full panel, overhang included, because the canvas is clipped to the panel (D19).
- **Sweep guard.** The tracking area also has `.mouseMoved`, so the hosting view gets moves while the pointer is inside the panel, and only then. Each move goes to the state machine as `pointerMoved(x:time:)`. During peek, if the horizontal speed since the previous move is above `NotchHoverStateMachine.sweepSpeed` (600 pt/s), the open delay starts again. A pointer that slows down or stops opens 0.12 s later as usual. Vertical speed is ignored, so approaching the notch from below is unaffected.

**Evidence:**
- Device log, 2026-10-25: 17 of 32 failed peeks exited at exactly y = 1112, the screen's top edge. A pointer pushed against the top edge reports y = maxY, and a frame ending at maxY counts it as outside. That the window server delivers hover in a strip above the screen is [I: device check].
- `constrainFrameRect(_:to:)` is "invoked automatically … whenever a titled NSWindow object is placed onscreen and whenever its size is changed", and "subclasses can override this method to prevent their instances from being constrained" [V: https://developer.apple.com/documentation/appkit/nswindow/constrainframerect(_:to:)]. The panel is borderless, so the override is a safeguard.
- With `.mouseMoved`, "the owner of the tracking area receives mouseMoved(with:) messages while the mouse cursor is within the area" [V: https://developer.apple.com/documentation/appkit/nstrackingarea/options-swift.struct/mousemoved]. Whether that holds for a non-key panel of an inactive app, given `acceptsMouseMovedEvents` is false by default, is [I: device check].
- `NSEvent.trackingArea` raises an exception for anything other than entered, exited and cursor-update events [V: https://developer.apple.com/documentation/appkit/nsevent/trackingarea]. So moves can't be filtered to our area. If SwiftUI's own tracking areas deliver the same move again, it should carry the same timestamp, and the machine ignores moves that aren't later than the previous one [I: device check].
- The x position comes from `event.cgEvent?.location`, which is recorded with the event. Quartz flips y but not x, so x is on the same axis as AppKit's screen coordinates. `NSEvent.mouseLocation` is the fallback, but it gives the position when the event is handled, not when it happened.

**Alternatives considered:**
- Count a pointer at y = maxY as inside by checking `NSEvent.mouseLocation` on exit. Rejected: the closed notch would still never get an enter event from the top row.
- A global mouse-moved monitor for the sweep guard. Rejected under D5: moves are only needed while the pointer is inside the panel.
- A longer open delay instead of the guard. Rejected: the 0.3 s delay felt slow on the device (D18).

**Why:**
- The speed is measured between consecutive moves, not smoothed. That is simple and testable, but a jittery hand could read as a sweep [I: device check]. The threshold is one constant.
- Moves that change nothing aren't logged, because they arrive many times a second. During a sweep each move still restarts the timer (a cancel and a new `Task`) and logs it. That's about 120 a second, but only for the length of the sweep. It's a performance-optimizer item for the Phase 2 pass.

**Trade-off:** if a display is arranged directly above the notched screen, the 1 pt overhang lies on that display's bottom row. A pointer resting there over the notch could peek or open it [I: device check, RISKS §4].

## D21. The registry owns the enabled flag; Now Playing is a stub behind `NowPlayingSource`

**Date:** 2026-10-25 · **Status:** Accepted (Shash; dropping `isEnabled` from `NotchModule` approved as Phase 2 decision 3)

**Decision:**
- `NotchModule` is the protocol in ARCHITECTURE.md §3 without `isEnabled`. `ModuleRegistry` keeps `enabledIDs` and saves each flag in `UserDefaults` under `module.<id>.enabled` (on when absent). `setEnabled(_:_:)` is the only writer; it calls `start()` or `stop()` only while the registry is running, so a disabled module, or any module before launch finishes, runs nothing.
- Layout slots (D8) are three properties on the registry: `compactLeftID`, `compactRightID`, `tabOrder`. They have defaults only: no persistence or editing until Phase 3 Settings.
- `NowPlayingModule` reads an `AsyncStream<NowPlayingInfo?>` from a `NowPlayingSource` in a `Task` that `start()` creates and `stop()` cancels. `NoNowPlayingSource` never yields, so the view always shows "Nothing playing". In Phase 2 the protocol had no playback commands; Phase 3 adds `send(_:to:)` and the Music and Spotify source (D22–D24).
- `NotchRootView` shows the first enabled module's `expandedView()` over the open shape.

**Alternatives considered:**
- Keep `isEnabled` on each module, as the first sketch had. Rejected: the module would have to tell the registry and the view when it changes, which means a second flag or manual observation.
- `ForEach` over `any NotchModule` for tabs. Not needed until there is a tab bar.

**Why:** One owner of the flag is simpler to test and makes the view update through Observation. The stub exercises the full start, consume and stop path without a permission prompt.

**Trade-offs / follow-ups:**
- The protocol's `compactView(slot:)` and `settingsView()` have no caller yet: the closed panel is exactly the notch (D5), so there is no room for compact content until the closed frame can widen.
- Panel name (Shash, 2026-10-25): `NotchPanel.title` is "DropNotch", so VoiceOver meets a named window instead of an unnamed one on every Space. Alternative: hide the panel from VoiceOver, rejected because the open notch will hold real content. `setAccessibilityLabel` is not set as well: it would be redundant, and VoiceOver might read the name twice [I: not checked on a device]. What VoiceOver announces is unverified.
- Device check (passed on a notched Mac, 2026-10-25, by recording): six centred opens, the placeholder centred inside the shape, no spill on close. Reduce Motion and Accessibility Inspector were not tested; they move to the Phase 3 accessibility checks (TASK.md).
- Original device check: the placeholder text appears when the shape opens, and nothing flickers or shifts during the grow or shrink (D19). Unverified; tests don't cover rendering.
- Later lists from the reviews are in TASK.md (Phase 3 carry-overs) and RISKS.md §4.

**Review (TASK.md step j):**
- `code-reviewer`: approved with suggestions. Applied: the removal transition (module content leaves at once on close), a `precondition` that module ids are unique, and test teardown.
- `test-writer`: extended the registry and Now Playing tests; 56 tests in total.
- `performance-optimizer`: an idle Debug build measured 0.0–0.1 % CPU with 0 idle wake-ups over 12 samples. Not measured: pointer inside the panel, a Release build, long-run memory.
- `accessibility-auditor`: no blockers. Its Later items are in TASK.md.
- `docs-writer`: ARCHITECTURE.md §2, §3 and §9 updated to match the code.
- Unverified: the device check above; the 56-test figure and the measurements are as reported by those agents, not re-run by `docs-writer`.


---

## D22. Player commands are raw Apple Events sent to the running app's pid

**Date:** 2026-10-25 · **Status:** Accepted (Shash, Phase 3 plan). Refines D2's "Apple Events (AppleScript)".

**Decision:**
- Commands and the one-off read at start are built with `NSAppleEventDescriptor` from the event codes in each app's scripting dictionary [V: `sdef`, docs/research/now-playing-probe-2026-10-25.md]:

| | Music | Spotify |
|---|---|---|
| Play/pause | `hookPlPs` | `spfyPlPs` |
| Next | `hookNext` | `spfyNext` |
| Previous | `hookBack` (restarts the track, then goes back; Shash) | `spfyPrev` |
| Read | `core`/`getd` on `pPlS`, and `pnam`/`pArt` of `pTrk` | same, plus `ID  ` of `pTrk` (the track id, for the ad rule in D24; `sdef` type text) |

- Each event is addressed to the pid of the running `NSRunningApplication`, never to the bundle ID, so a player that quit between the check and the send isn't relaunched [I: device check 4]. On the Apple Event queue, just before each permission check, send or read, the pid is checked to still belong to the player's bundle ID: the prompt can stay up for minutes, and a quit player's pid could be reused (security-auditor L1, 2026-10-25).
- Sent with `sendEvent(options: .waitForReply, timeout: 2)` on one serial `DispatchQueue`, so commands stay in order and nothing blocks the main thread. Bridged to async with `withCheckedContinuation`.
- The reply's error number is checked as well as the thrown error [I: whether `sendEvent` throws for a handler error isn't stated in Apple's docs].

**Alternatives considered:**
- `NSAppleScript` with `tell application id …`: easiest to read, but it launches a player that isn't running, has no timeout parameter, and compiles script text [I].
- ScriptingBridge (`SBApplication`): can launch the target on first use, and in Swift it needs generated headers or untyped key-value code [I].

**Why:** pid addressing and a short timeout give the two guarantees that matter: never launch a player, never hang behind one. A local reply normally takes milliseconds; 2 s gives up on a hung player instead of queueing clicks behind it.

**Trade-offs / follow-ups:**
- The codes come from the players' dictionaries, which can change with an update. A wrong code fails with an error and maps to `.failed`, not a crash (D23).
- Device checks 4 (never launch) and 9 (hung player) in TASK.md Phase 3.

---

## D23. Automation permission: checked silently at start, asked on the first click

**Date:** 2026-10-25 · **Status:** Accepted (Shash, Phase 3 plan decisions 2 and 3)

**Decision:**
- At start, for each running player, `AEDeterminePermissionToAutomateTarget(…, askUserIfNeeded: false)` runs on the Apple Event queue. It never prompts. Only if it returns `noErr` is the current state and track read (D22). Otherwise nothing is sent and the module waits for the player's next notification (D24).
- The first click on a control calls it with `askUserIfNeeded: true` on the same queue, then sends. That call blocks until the user answers the system prompt [I], so it never runs on the main thread. While a command is in flight, further clicks are dropped (since D27 the controls are no longer drawn disabled, which dimmed them on every click). Every later click calls it again, so a grant turned on in System Settings works without a relaunch [I: device check 2].
- The permission check uses the play/pause event for the target app; Automation consent is per target app [I].
- Every event is sent with `kAEDoNotPromptForUserConsent`, so a send or read fails with -1744 instead of prompting, and only `permission(ask: true)` after a click can show the prompt (security-auditor M1, 2026-10-25) [I: from the SDK header `AppleEvents.h`; not seen on a device].
- No custom screen before the system prompt: the prompt shows our `NSAppleEventsUsageDescription`, and the click that triggers it is the explanation.
- "First enabled" in CLAUDE.md and ARCHITECTURE §10 means first use here: Now Playing is on by default (D21), so asking when it is enabled would mean asking at launch.
- Outcomes, mapped by one pure function:

| OSStatus | Meaning | Outcome |
|---|---|---|
| 0 | noErr | `.ok` |
| -1743 | errAEEventNotPermitted | `.denied` |
| -1744 | errAEEventWouldRequireUserConsent | `.needsConsent` |
| -600, -609 | procNotFound, connectionInvalid | `.notRunning` |
| -1712 | errAETimeout | `.timedOut` |
| anything else | | `.failed(code)` |

- `.denied` shows "Allow control of <player> in System Settings" in place of the artist line, as a button that opens Privacy & Security › Automation (`x-apple.systempreferences:com.apple.preference.security?Privacy_Automation` [I: undocumented URL]; if it fails, the text still says where to go). The controls stay, so a retry works after a grant. Track info keeps updating from notifications, which need no permission. Other outcomes are logged only.

**Alternatives considered:**
- Our own explanation screen before the prompt (RISKS §2). Rejected by Shash: more UI for one prompt per player, and the prompt already comes straight after the user's own click.
- Ask at launch, or when the module is enabled. Rejected: prompts with no context, and D21 enables the module by default.
- Skip the read at start. Rejected by Shash: a returning user would see only the player name until the next track change.

**Why:** No prompt appears unless the user clicked a control for that player, and no permission state can crash the app.

**Trade-offs / follow-ups:**
- The usage string now covers reading the current track (project.yml).
- A user who denied earlier sees normal controls until the first click shows the denied state.
- Device checks 1–3 in TASK.md Phase 3 settle the deferred step i items (one prompt per target app; grants after re-signing).

---

## D24. Track info from distributed notifications; one player chosen; no timers

**Date:** 2026-10-25 · **Status:** Accepted (Shash, after the step 1 probe)

**Decision:**
- Observe `com.apple.Music.playerInfo` and `com.spotify.client.PlaybackStateChanged` with `suspensionBehavior: .deliverImmediately`. The probe saw no suspension for a never-active app, but DropNotch becomes active while Settings is open (D14), and Apple documents that delivery can be suspended [I: device check 7]. It costs one argument.
- Payloads: `Player State` (`Playing`/`Paused`/`Stopped`), `Name` and `Artist` [V: probe]. A payload with only `Player State` (Music between tracks, launch, quit) updates the state and keeps the last track. Only quitting clears a player (`NSWorkspace` did-terminate). Titles and artists are trimmed and an empty string counts as missing; with no title the view shows the player's name. A Spotify `Track ID` starting with `spotify:ad:` is treated as an ad: no title or artist [I: device check 14]. The read at start applies the same rule through the same function, using the track's `ID  ` property; whether that returns `spotify:ad:…` for an ad is also [I].
- Bursts (Music sends two states within 25–85 ms) are not debounced. The latest state is shown; a possible ~90 ms icon flicker is device check 10. If it shows, a one-shot 150 ms debounce goes in ARCHITECTURE §9.
- Which player is shown, a pure reducer (`NowPlayingSelection`):
  1. Among players whose latest state is `Playing`, the one that reported most recently. So with both playing, pausing the one on screen switches to the other; and each Music track change (a `Stopped` about 70 ms before the new track) briefly shows the other player [I: device check 6].
  2. Otherwise the player that most recently reported any state. Pausing doesn't hand over to the other player.
  3. A player that quits drops out. A state-only payload from a player that isn't known to be running is ignored: both players post one on quit, and it can arrive after `NSWorkspace`'s quit notice (code-reviewer, 2026-10-25).
  4. A running player whose state is unknown (no notification yet, no read allowed) shows only when no player has a known state; Music before Spotify. It shows the player name and controls, which is the way to the first prompt.
  5. Neither running: "Nothing playing".
- No timers or polling. Nothing is added to ARCHITECTURE §9's timer table. (Still true with D26: the progress bar is animated by Core Animation, not an app timer.)

**Alternatives considered:**
- The block-based `addObserver(forName:object:queue:using:)`: it can't set the suspension behaviour.
- "Stopped clears the track" (the first plan). Rejected by the probe: it blanks the title on every Music track change.
- Debounce every notification. Rejected until the device shows a flicker: it adds a timer for a ~90 ms artefact.
- Show both players. Rejected: no room in the open shape, and the MVP needs one set of controls.

**Why:** Notifications arrive at a background app with no permission and no wake-ups between changes. The selection rules keep the player the user last touched on screen.

**Trade-offs / follow-ups:**
- The notification names and keys are undocumented and can change with a player update (RISKS §4). If they change, track info stops arriving; controls still work.
- Spoofing (security-auditor, 2026-10-25): distributed notifications carry no sender, so any local process can post these names. Notifications for a player that isn't running are dropped, and text is trimmed and capped at 256 characters. A spoofed notification while the player is running can still change what the notch shows (and so whether the button reads Play or Pause). Known limit.
- Impostors: an app that reuses Music's or Spotify's bundle ID would receive our events and be named in the prompt. The events carry no user data. Checking the target's code signature is deferred; known limit.
- Device checks 5–7, 10, 13 and 14 in TASK.md Phase 3.
- Device check (Shash, 2026-10-25, Release build on a notched Mac): Now Playing works for Music and Spotify, with title, artist, play/pause, next and previous all correct. Switching between the two players works: checks 5 and 6 passed. Checks 1–4 and 7–16 have not been tested and remain open, to run before release.

---

## D25. Spotify artwork is DropNotch's first network access: one HTTPS GET per track to i.scdn.co

**Date:** 2026-10-25 · **Status:** Accepted (Shash, `feat/now-playing-media` plan, decisions 2 and 7)

**Decision:**
- Spotify artwork comes from the track's `artwork url`, read by Apple Event only when Automation is already granted (D23). Its notification carries no URL [V: docs/research/now-playing-probe-2026-10-25.md]. Without the grant the view shows Spotify's app icon.
- One GET per Spotify track id, and only if the URL is `https`, host exactly `i.scdn.co`, no user or password, port 443 or none [V: host seen by the probe, docs/research/now-playing-media-probe-2026-10-25.md].
- `URLSession` with an ephemeral configuration: no cookie storage, no URL cache, no credential storage. Redirects are refused. Request timeout 10 s.
- Accepted: status 200, a MIME type of `image/jpeg` or `image/png` as `URLSession` reports it (it infers the type from the bytes when the header is missing or names another image type [V: test-writer stub, 2026-10-25]), at most 2 MB (the probe saw 39–61 KB). Decoded off the main thread to a small thumbnail with ImageIO, held in memory only, one per player.
- Any failure shows the app icon. No retry until the track changes. The URL is never logged; only the outcome.
- Music artwork needs no network: it is read from Music by Apple Event (D26).
- What leaves the Mac: the GET request with `URLSession`'s default headers (including a User-Agent naming DropNotch and the CFNetwork and Darwin versions [I: exact header set]), the Mac's IP address, and the host name in TLS. The URL names an image Spotify itself chose for the track Spotify is playing.
- No entitlement or Info.plist key: DropNotch is unsandboxed (D4), so the sandbox's outgoing-network entitlement doesn't apply [I: confirm on Apple's entitlement page]. The default App Transport Security rules accept a valid-TLS host [I].

**Alternatives considered:**
- Spotify's public oEmbed endpoint: no Automation grant needed, but a second host, and the request carries the track id. Rejected by Shash.
- No Spotify artwork (app icon only). Rejected: artwork is the "song icon" for the compact branch.
- A disk cache. Rejected: one image per player in memory is enough, and nothing about listening is written to disk.
- An "artwork downloads" off switch now. Deferred by Shash to Phase 3 Settings.

**Why:** the only request goes to the image server of the app that is already playing the track, carries nothing DropNotch knows beyond the URL Spotify gave it, and fails safely to the app icon.

**Trade-offs / follow-ups:**
- README Privacy, ARCHITECTURE §10 and RISKS §4 now describe this request.
- Images are untrusted input to ImageIO, from the network and from Music's embedded artwork alike. Only JPEG and PNG (as ImageIO identifies the bytes) are decoded, images over 8192 px on a side are refused from their header, and decoding goes straight to a thumbnail (security-auditor M1, L5, 2026-10-25).
- Spoofing: a local unsandboxed process flooding Music or Spotify notifications with new track ids makes DropNotch read the player once per notification (and Music's artwork once per id). The reads can't choose the artwork URL or show the spoofer's image; known limit, like D24's.
- Device check 21 (TASK.md Phase 3, branch 2): only `i.scdn.co`, at most one request per Spotify track, none for Music, none while idle.

---

## D26. Progress, artwork reads and seek; favourite dropped

**Date:** 2026-10-25 · **Status:** Accepted (Shash, after the step 0 probe)

**Decision:**
- Units, all normalised to seconds [V: probe]:

| Value | Music | Spotify |
|---|---|---|
| Notification duration | `Total Time` ms | `Duration` ms |
| Notification position | none | `Playback Position` s |
| Apple Event `pDur` | s | ms (its dictionary says seconds) |
| Apple Event `pPos` | s | s |

- `NowPlayingInfo` gains a track id (Music: `PersistentID` as unsigned upper-case hex, which equals `persistent ID`; Spotify: `Track ID`, which equals `id`), a duration, a position anchor (seconds at a time; rate fixed at 1, since scripting reports none), the Spotify artwork URL and the artwork thumbnail.
- Reads, all only after `permission(ask: false)` returns `.ok`, so none can prompt (D23):
  - Music: position, duration and id after every notification that carries a track (its notification has no position; reads between tracks fail with -1728).
  - Spotify: position, duration, id and artwork URL when a track id is first seen, which includes launch (its launch notification's position is unreliable [V: probe]). Other Spotify notifications carry position and duration.
  - Both: the position each time the notch opens, because seeks by Apple Event send no notification and seeks in the player's window may not [V: probe; the second I].
  - Both: the position once after a seek that returned `.ok`.
  - Music artwork (`raw data` of artwork 1 of the current track) when Music's track id changes. Capped at 10 MB (the probe saw about 0.5 MB).
- -1728 and non-number replies mean unknown, never zero.
- Merging (`NowPlayingSelection`): a state-only payload keeps every track field and re-anchors the position where it was; a payload with the same track id keeps the artwork and URL; a new track id drops artwork, URL and position. A read merges only while the player is on the same track: duration and artwork URL always, the position only if no newer report arrived meanwhile (code-reviewer, 2026-10-25). It doesn't count as a report for choosing the player on screen. The once-per-track read and artwork markers reset on any track change (an ad included) and on quit. Artwork is accepted only for the track id it was fetched for.
- The bar: a thin layer animated by Core Animation from the current fraction to 1 over the remaining time, while playing; still while paused; restarted from the new anchor on every update. The app runs no timer for it [V: probe, 0 wake-ups]. It exists only while the notch is open, because the open content is removed on close (D19).
- Seek: click or drag on the bar sends `core/setd` on `pPos` through the same click path as the other controls, so the first one may show the Automation prompt (D23). VoiceOver adjusts in 10 s steps; the spoken value is redrawn once a second only while VoiceOver is on and playing, and after an adjust it speaks the requested position until the new one arrives. A refused request is announced (accessibility-auditor, 2026-10-25).
- Reduce Motion: the bar keeps moving. It is a slow (about 2 px/s) progress fill with no zoom, parallax or bounce, it stops when paused, and closing the notch hides it (accessibility-auditor, 2026-10-25). The track is 40 % white (3.7:1 on black), 50 % under Increase Contrast.
- Favourite is not built. `favorited` (`pLov`) read true for a catalogue track that Music's own menu showed as not a favourite [V: probe, Shash], so the button would show the wrong state.

**Alternatives considered:**
- `TimelineView` redrawing once a second: 0.1–0.6 % CPU and 1 s steps [V: probe]. Kept as the fallback if the layer misbehaves on the device.
- `ProgressView(timerInterval:)`: smooth, but about 12 % CPU while visible, and its style can't be made thin [V: probe].
- The native `Slider`: free drag and VoiceOver support, but it has a knob. Shash chose a custom thin bar.
- Reading Spotify on every notification: unneeded, since its notifications carry position and duration (Shash).
- Favourite with a warning, or only for library tracks: rejected; the probe could not show where `pLov` is right.

**Why:** every value the bar shows comes from an event or a read the user caused, and the motion between them costs the app nothing.

**Trade-offs / follow-ups:**
- A seek made in the player's own window while the notch is open may not show until the next notification or open [I: device check 18].
- The bar's animation is capped at 10 fps: uncapped it added about 12 points of WindowServer CPU, capped about 3 [V: performance-optimizer harness, 2026-10-25]. The elapsed-time text updates about once a second while open and playing (about 0.5 % app CPU), and screen sleep now closes the notch so neither runs while the display sleeps (ARCHITECTURE §9).
- Revisit favourite if a later probe finds `pLov` reliable for some tracks.

## D27. Now Playing UI feel: optimistic play/pause, glass controls, crossfades

**Date:** 2026-10-31 · **Status:** Accepted (Shash asked for the four changes; the details below are the lead's, reviewed by code-reviewer)

**Decision:**
- Play/pause flips the icon (and its VoiceOver label) on click. The flip is cleared by an update that agrees, by a change of player, at once by a failed command, or 1 s after an `.ok` reply that no update confirmed (a command that changed nothing). A disagreeing update never clears it, before or after the reply, because Music's bursts (D24) can land on either side. With the state `.unknown` (no notification, no grant) nothing flips: it would be a guess while the Automation prompt is up.
- The controls and the bar are no longer `.disabled` while a command is in flight. `perform` still drops those clicks (D23).
- Play morphs into pause with `contentTransition(.symbolEffect(.replace))`; under Reduce Motion it fades instead.
- Controls on macOS 26+: `glassEffect(.regular.interactive(), in: .circle)` in a custom `ButtonStyle` [V: macOS 27 SDK swiftinterface; developer.apple.com "Applying Liquid Glass to custom views": interactive glass reacts to pointer and presses]. On macOS 14/15: a white circle at 12 % on hover, 25 % pressed (20 %/35 % with Increase Contrast), and a 0.9 press scale, which Reduce Motion turns off. The notch background stays solid black.
- Title, artist and artwork crossfade over 0.2 s on a change. A fade is what Reduce Motion substitutes for motion (L8), so the crossfades stay on under it.

**Revision (2026-10-31, after Shash's clip):**
- Root cause of the time jumps: `PlaybackProgressView` took "now" from `TimelineView`'s `context.date`. While the timeline is paused (always, unless VoiceOver is on), that date stays at the view's first render [V: scratch probe, 2026-10-31: 0.23 s while real time ran to 5 s]. After any update while playing, the elapsed text ran ahead by however long the view had existed, and snapped back on pause. The bar was right: it uses its own clock. The view now uses `Date()`.
- Music's play/pause burst is the old state first, then the new one 8–100 ms later, both carrying the track; its position read lags and jitters by a few tenths of a second, never 0 [V: probe, 2026-10-31].
- The module keeps `shown` (what the view draws) apart from `info` (what the source reported). A click freezes (pause) or resumes (play) at the position on screen; a seek moves the bar to the target at once. On the same track, a position that is missing, or within 1 s of `shown`, carries on from `shown`: while paused either way, while playing only backwards (`NowPlayingInfo.steadied`). A failed command or a settle takes the player's position as it is.
- Artwork: on a track change the last picture stays until the new one loads, then crossfades straight to it. The app icon appears only when the source says the load found none (`artworkMissing`), or after a 2 s hold (a failed read never says either).
- Text: the old title and artist fade out over 0.12 s, then the new ones fade in over 0.12 s, so they never overlap.
- Glass (and the macOS 14/15 circle) shows only while the pointer is over a control or it is pressed.

**Alternatives:**
- Reconcile with the first update after the reply, plus an extra read. Rejected (code-reviewer W1, W3, W4): the read doesn't carry the play state (`NowPlayingSelection.refreshed`), `publish` drops unchanged values so nothing may arrive, and a late burst would flicker the icon.
- Make the read after a command authoritative for the play state. Rejected for now: it changes D24/D26 selection merging for a corner case the 1 s settle already covers.
- `.buttonStyle(.glass)`. Rejected: Apple's docs don't say how it sizes a button or whether it honours `buttonBorderShape`, and the controls need a fixed 32 pt circle (L7).
- `GlassEffectContainer` around the three controls, which Apple advises for rendering cost. Deferred (`shortcut:` comment): its `spacing`, which decides when shapes merge, isn't documented. performance-optimizer measures it in the release branch.

**Trade-offs / follow-ups:**
- The settle is a one-shot 1 s sleep per play/pause click (ARCHITECTURE §9).
- Unverified, release checklist: whether interactive glass shows a hover effect on macOS, and whether its press bounce respects Reduce Motion; the white hover circle in the non-activating panel on macOS 14/15; whether a late Music burst still flickers the icon; artwork on a track change fading old → new directly, the app icon only when missing or after the 2 s hold.
- While playing, the steadying holds a read that is behind by under a second, so the screen can run up to a second ahead of the player. Each pause takes a read in the same whole second as the screen, which resets that lead without a visible change. A difference of 1 s or more is taken as a seek in the player's window and applied.
- Hover feedback relies on SwiftUI `onHover` in the non-activating panel [I: device check].

---

## D28. Compact slot: the closed shape widens while music plays (revises D5)

**Date:** 2026-10-31 · **Status:** Accepted (Shash approved the width, the animation and the 5 s grace)

**Decision:**
- While a module fills a compact slot (D8), the closed shape is the notch plus one square wing on each side, as wide as the notch is tall: about 32 pt, so about 250 pt in all on a 14" MacBook Pro. The pill on a screen without a notch widens the same way. Peek grows from that wider shape; the open size is unchanged.
- Now Playing fills both slots by default: artwork on the left (the open notch's `NowPlayingArtworkView`, smaller), 4 decorative bars on the right (D2).
- In: the panel grows first, then the shape widens with the hover spring (0.25 s, no bounce) and the artwork and bars fade in. Out: the shape shrinks with the same spring, then the panel shrinks (D19). The wing content is clipped to the shape, so it never shows outside it mid-animation. Reduce Motion: the width changes at once and the bars stay still.
- When to show: while playing, and for 2 s after playback pauses or stops while a track is still loaded (5 s until the revision below). Playing again within 2 s keeps the wings. No track (the player quit) retracts them at once.
- The bars animate only while playing, the display is awake, Low Power Mode is off and Reduce Motion is off. Otherwise they are still: flat while paused, a fixed uneven pattern while playing. Core Animation draws the motion, capped at 15 fps, so the app does no work between frames (as the progress bar, D26).
- The wings are part of the panel: hovering them peeks and opens the notch, like the notch itself.

**Alternatives:**
- Keep the wings while paused for as long as a track is loaded. Rejected (Shash): the menu-bar strip under them would stay blocked for hours after a pause.
- Retract on pause at once. Rejected: a quick pause and play, or one of Music's bursts (D24), would make the shape flap.
- Narrower (0.8 × height) or wider (height + 8 pt) wings. Rejected (Shash): a square wing fits the artwork with even padding.
- A SwiftUI `TimelineView` or `repeatForever` animation for the bars. Rejected: each frame would be a SwiftUI update in the app; the render server already proved cheap for the progress bar (D26).

**Consequences / follow-ups:**
- While the wings show, menu-bar items under them can't be clicked (they reach the panel instead). macOS keeps status items clear of the notch itself, not of the 32 pt beside it [I: device check].
- The grace is a one-shot 2 s sleep per pause (ARCHITECTURE §9).
- 15 fps is a guess at what looks smooth at this size. Device check; performance-optimizer measures WindowServer cost in the release branch.
- Toggling Low Power Mode mid-song takes effect at once (power-state notification); screen sleep and wake stop and restart the bars.

**Revision (2026-10-31, after Shash's device check: the bars seemed to keep going after a pause):**
- The bars freeze flat on the update that pauses: the player's paused notification, or the optimistic flip of a click in the notch (D27), never the player's confirmation. Their Core Animation animations are removed, not left to finish a cycle.
- Root cause: not found in DropNotch's code. The path from a paused update to the bars was already immediate. Measured in the test host: the animations are gone within one SwiftUI render pass of the module seeing the pause (about 10 ms), and on the click before the player replies. The source publishes a paused notification straight away (`.deliverImmediately`, no read first), and neither the selection nor the steadying holds a state back. Shash confirmed on the device (2026-10-31): the delay was the old 5 s grace, with the wings still showing. Before that, two candidates remained, both outside the view: the player's notification arriving late, or the 5 s wings, flat bars and all, reading as "still running". To tell them apart on the device, `log stream` shows the source's "reported paused" line next to the bars' new "Bars still" line.
- Tests: the bars stop in the same call as `update(isPlaying: false)`, on the render pass after a paused update, and on the click before the player confirms. Each one fails if `removeAllAnimations()` is taken out.
- The grace is 2 s instead of 5 s (Shash). That still covers a quick pause and play, and Music's bursts, which are 8–100 ms apart (D27).

---

## D29. Panel frames are whole points; the shape fills the strip above the screen

**Date:** 2026-10-31 · **Status:** Accepted (Shash asked for the overdraw after device check 27)

**Root cause:** AppKit rounds a window's frame to whole points, origin down and size up, even on a 2x display [V: probe, 2026-10-31, 240 frames, 0 exceptions]. The closed panel is 37.5 + 1 pt tall on a 14" MacBook Pro, so AppKit put its bottom 0.5 pt lower than asked, while `NotchPanel` placed the canvas for the asked frame. Everything drew 0.5 pt low, and with the shape starting 1 pt below the canvas top, the screen's top pixel row showed wallpaper. It was hidden by the hardware notch until the wings (D28); the open frame is whole points, so it was flush.

**Decision:**
- `NotchPanel` asks for the smallest whole-point frame around the geometry's frame (`NSIntegralRect`), which AppKit keeps as is, and places the canvas for that frame.
- The shape is drawn at the panel frame's height, from the canvas top: it fills the 1 pt strip above the screen (D20) in every state and during every animation, so its top edge is always off-screen. Content is pushed down by the same 1 pt.
- Tests: the shape's top is at or above the screen's top in every phase, with and without wings, at 1x and 2x, against the probe's rounding rule; and a real panel keeps the whole-point frame.

**Alternatives:** Whole-point frames in `NotchGeometry` itself. Rejected: the shape frames would lose their pixel alignment to the hardware notch; only the window needs whole points.

**Trade-off:** the panel can be up to 1 pt wider and 1 pt taller than the shape at its bottom and sides, so the hover area grows by that much.

## D30. Global hotkey opens the notch with keyboard focus (revises D16)

**Date:** 2026-10-31 · **Status:** Accepted (Shash chose ⌃⌥N, 2026-10-31; closes carry-overs L1–L3)

**Decision:**
- `KeyboardShortcuts.Name.toggleNotch`, default ⌃⌥N (not a macOS default; ⌃⌥Space switches input source, ⌥⌘Space opens Finder search). Listened to through `KeyboardShortcuts.events(.keyDown, for:)`, the package's recommended API; not registered in the test host. Rebinding comes with Settings.
- The hover machine gains `.hotkeyPressed` and `.dismissed` and an `openedByKeyboard` flag. The hotkey toggles the flag: from closed or peek it opens; from a hover-opened notch it takes focus instead of closing under the pointer; a second press closes. While the flag is set, the pointer leaving doesn't close the notch. `.dismissed` (Escape, or the panel losing key status, e.g. a click in another app) closes only a hotkey-opened notch.
- `NotchPanel.canBecomeKey` follows the flag, so hover still never takes keyboard focus (D16 kept for hover). `NotchState` makes the panel key on open (non-activating, so DropNotch is never activated) and, on close, orders the panel out and straight back in, which hands key focus back to the app in front: that app stayed active throughout [I: window-server behaviour; device check].
- Controls are `.focusable(interactions: .edit)`: `.activate` focus needs the system's keyboard-navigation setting on macOS [V: developer.apple.com, FocusInteractions]. Tab moves between them, the arrows step through them in reading order (stopping at the ends), Space and Return press the focused one, play/pause starts focused. A focused control shows the hover circle.
- Escape is handled twice, idempotently: `NotchPanel.cancelOperation` and `.onExitCommand` on the root view, because SwiftUI can consume Escape while a control is focused [I].

**Alternatives:** Hotkey on a hover-opened notch closes it (rejected: the notch would close under the pointer and re-opening needs the pointer to leave first). A separate key panel for keyboard use (rejected: two windows to keep in sync). Panel-level AppKit key handling with a hand-drawn focus index (rejected: more code, and the module would have to publish its controls).

**Not done (L3):** keeping the notch open while VoiceOver focus is inside a hover-opened notch; the progress bar is not reachable by keyboard (VoiceOver can still adjust it).

---

## D31. Notes: one plain-text note in its own tab; tabs beside the camera housing

**Date:** 2026-10-31 · **Status:** Accepted (Shash chose tabs over side-by-side, 2026-10-31)

**Decision:**
- `NotesModule` keeps one note in `~/Library/Application Support/DropNotch/Notes/note.txt` (UTF-8). It loads in `start()`, saves 1 s after the last edit (one-shot task, restarted per edit), and flushes in `stop()`, which the registry calls at quit. Writes are atomic. A missing file is an empty note; a file that exists but can't be read turns saving off and shows "Couldn't open the note file", so it is never overwritten. A failed save shows "Couldn't save the note" under the editor until a save succeeds. A note deleted while the module is off starts empty and isn't written back. Logs carry error domains and codes only, never the text or the path. No network.
- Reads and writes run on the main thread: a note is a few KB [I: not measured]. Marked `shortcut:` in the code.
- Modules share the open notch as tabs: one icon per enabled module (`NotchModule.systemImage`) in the strip left of the camera housing, so the open size (480 × 150) doesn't change. The selected tab has a filled capsule as well as brighter colour (L6). ⌘1, ⌘2… switch tabs while the panel is key; the tabs are not Tab stops, so Tab stays with the module's controls. The selection lasts for the session.
- ⌃⌥N opens on the last tab. On Notes the text view takes focus at once (the same explicit `onChange(initial:)` as Now Playing, D30).
- A click in a hover-opened note takes keyboard focus through the hover machine's `.focusRequested`, which opens with keyboard focus like the hotkey but never toggles closed. Without it the cursor would sit in the note while the keys went to the app in front. The click lands on a clear overlay, so it doesn't place the cursor.
- Escape is caught in `NotchPanel.sendEvent` for the whole panel, because NSTextView keeps Escape for word completion and it would never reach `cancelOperation` or `.onExitCommand` [I: AppKit behaviour; device check 40]. While an input method has marked text, Escape goes to it.

**Alternatives:** Side-by-side, about 760 pt wide (rejected by Shash: covers more of the menu bar, and the file tray and clipboard need tabs anyway). A tab bar below the content (rejected: it adds height; the strip beside the camera housing is free). `.onKeyPress(.escape)` on the editor (rejected: per view, and depends on how SwiftUI's text view routes keys). Saving off the main thread (deferred: ordering a background write against the flush at quit is more code than a few-KB write is worth).

**Not done:** several notes, rich text, search, sync; keeping the last tab across relaunches; Tab and Shift-Tab out of the note (Tab types a tab). An edit made to note.txt outside DropNotch while it runs is overwritten by the next edit in the notch, and two running copies overwrite each other (code-reviewer S5). VoiceOver can focus the editor in a hover-opened notch without the panel taking keys (S4): for the release accessibility pass.

---

## D32. File tray: drops on the whole notch, copy-only drags, bookmarks resolved when shown

**Date:** 2026-10-31 · **Status:** Accepted (implements D6; no new choice for Shash: each point below follows D6 or "files stay where they are")

**Decision:**
- `FileTrayModule` keeps the list in `~/Library/Application Support/DropNotch/tray.json` (atomic JSON, saved on every change) and fallback copies in `…/DropNotch/Tray/<UUID>/<name>`. An unreadable tray.json turns saving off and shows "Couldn't open the tray file", as for notes (D31). Logs carry error domains and codes only, never names or paths.
- `NotchHostingView` is the drag destination for file URLs and file promises in every state (closed, compact, open). Mouse tracking pauses during a drag, so drag enter and exit stand in for the pointer (`.pointerEntered` / `.pointerExited`): the notch peeks, opens after the usual delay, and switches to the Tray tab. Per dragged item a file URL is taken before a promise, so a file is bookmarked (D6). The drop operation is `.copy`, else `.link`, never `.move` or `.generic`: Finder treats those as a move, and the original would leave its folder.
- Bookmarks are plain (unsandboxed, D4), resolved with `.withoutUI, .withoutMounting`, when the tray is shown or a drop arrives, not at launch, so a Desktop/Documents/Downloads prompt appears in context. Usage strings for those three folders are in project.yml. A stale bookmark is rewritten. A file that is gone, or that the bookmark followed into the Trash, is missing: greyed, badged with a question mark, named "missing" for VoiceOver, not draggable.
- A dropped symlink is followed: the tray holds the file the user meant. A file already in the tray isn't added twice. If `bookmarkData()` fails the file is copied (off the main thread). Promised files are written by the source app into a fresh folder; a file it reports outside that folder is ignored.
- Removing an item, or Clear All, never touches an original; only the tray's own copy and its folder are deleted. A copy's path is built from a UUID folder and a single-component name, checked again when tray.json is loaded, so an edited file can't point a delete elsewhere; `removeItem` deletes a symlink, not its target.
- Drag out is an AppKit `NSDraggingSource` per tile (SwiftUI's `onDrag` can't set the operation): `.copy` outside the app, nothing inside, so Finder copies and the Trash refuses. Dragging a selected tile drags every selected file. Drags from the tray are never dropped back in (`draggingSource` is set only inside the app).
- Click selects, ⌘-click adds or removes. AirDrop (`NSSharingService(named: .sendViaAirDrop)`) and Share (`ShareLink`, the system share menu) act on the selection, or on every file when nothing is selected, so one dropped file needs no click first. Missing files are left out.

**Alternatives:** SwiftUI `.onDrop`/`.onDrag` (rejected: no control over the drag operation, and file-promise support through `NSItemProvider` isn't documented for macOS). Resolving bookmarks at launch (rejected: a folder prompt with no context). Bookmarking the symlink itself (rejected: dragging out would hand over a link). A package: none found worth adding (dependency-manager, 2026-10-31: only small MIT bookmark wrappers saving about 10 lines).

**Not done:** Quick Look and thumbnails (type icons only), open/reveal in Finder, text and web-link drops, keyboard access to tiles and actions (release accessibility pass), a size limit for copies, cleaning up a copy left behind by a crash mid-drop.
