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
- The `com.apple.security.automation.apple-events` entitlement (needed under the hardened runtime to send Apple Events to other apps such as Music and Spotify; not needed for same-team processes [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events]) and the `NSAppleEventsUsageDescription` key are added through `project.yml` in Phase 2.
- The usage text ("DropNotch sends play, pause and skip commands to Music and Spotify…") describes commands that don't exist yet. Re-check it whenever the Now Playing feature changes.

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

`NotchHostingView` sets `sizingOptions = []`, and the root view ignores the safe area.

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
- `sizingOptions = []` stops SwiftUI's preferred content size from fighting the frames that `NotchGeometry` sets.
- `.ignoresSafeArea()` matters because the panel sits over the camera housing. SwiftUI would otherwise push the content down out of the safe area [I: device check].
- ARCHITECTURE §6's `acceptsFirstMouse` override isn't added yet, because Phase 2 has no clickable controls.

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
- `NotchHoverStateMachine` is a value type. Its `handle(_:)` returns an effect (start the open delay, start the exit debounce, or cancel the timer). `NotchState` runs that effect with one cancellable `Task.sleep`, and starting a timer replaces the running one.
- Peek is the phase between the pointer entering and the open delay ending. The shape grows by `NotchGeometry.peekGrowth` (decision 2 of the Phase 2 plan, Shash).

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
- When the notch grows (to peek or open), `NotchState` sets the panel to the larger frame first, then animates the shape with a spring (0.35 s, bounce 0.15).
- When it closes, the shape animates first. The `withAnimation` completion then shrinks the panel to the current geometry's closed frame. It does this only if nothing has changed since the close started: no phase change and no screen change, tracked by a counter.
- When it grows while the panel is already larger than the target (re-entering during a close), the panel keeps its larger frame.
- With Reduce Motion on, the animation is `nil`, so the change is immediate.

**Evidence:**
- The `withAnimation(_:completionCriteria:_:completion:)` completion "will always be fired exactly one time", and right away when no animation runs [V: https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)]. This is macOS 14+, which matches the deployment target.
- The Reduce Motion setting is read from `NSWorkspace.accessibilityDisplayShouldReduceMotion` [V: https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion].

**Alternatives considered:**
- Animate the window frame itself with AppKit. Rejected: two animation systems would run against each other, and resizing a window every frame costs more than redrawing a shape.
- Keep the panel at the open size all the time. Rejected under D5: it would block clicks around the notch.

**Why:**
- The shape can only draw inside the panel. So the panel has to be big enough before the shape grows, and it can't shrink until the shape has finished shrinking.
- The counter matters because the pointer can come back, or a display can be unplugged, during the close animation. Without it, an old completion would shrink the panel at the wrong moment or move it back to the old screen's frame (code-reviewer W1).

**Trade-off:** for about 0.35 s after closing starts, the panel's larger, mostly transparent frame may still catch clicks and hover [I: device check; whether macOS passes clicks through fully transparent pixels is not documented]. Re-entering in that time peeks and then reopens the notch.
