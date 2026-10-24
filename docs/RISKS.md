# Risks

Status: Phase 1, 2026-10-24.

Tags: **[V]** verified (on a Canopy page, or in Atoll's source per the notes under [research/](research/)); **[I]** inferred (general platform knowledge, community knowledge, or reasoning, not checked against Apple documentation in Phase 1). Likelihood and impact ratings are judgements.

## 1. Private and undocumented APIs

Rule for all of these: the dependency sits behind a protocol in `Services/` with a public fallback. A failure turns off one feature, never crashes the app, and is never discovered at launch by a missing symbol. Bind private symbols at run time (`dlopen`/`dlsym`-style lookup) and check the result, never at link time. Atoll's link-time binding of private window-server functions has no graceful fallback [V: research/atoll-system-shell.md B2; failure mode I].

### 1.1 MediaRemote (generic now playing)

- **What:** the private framework that reports any app's now-playing session and accepts play/pause/seek commands. It is likely the only route to browsers, Netflix, Twitch and similar [I; that Canopy supports these is V: Canopy lists these sources; Atoll uses MediaRemote for them].
- **Since macOS 15.4:** MediaRemote stopped returning now-playing data to ordinary third-party processes [I: community knowledge; Apple doesn't document MediaRemote]. Atoll works around this by running an Apple-signed system interpreter (`/usr/bin/perl`) that loads a bundled adapter framework and streams JSON back over a pipe. At launch it also runs an availability check and falls back to Apple Music if the answer is yes [V: research/atoll-media-lockscreen.md §1–2]. Why the Apple-signed interpreter gets through is [I].
- **Likelihood of breaking:** high. Apple has already closed the direct route once, and the workaround depends on an Apple-signed binary keeping its access [I]. Atoll's check defaults to "available" when the test itself fails, so a future break may leave the feature silently empty [V: behaviour; consequence I].
- **Security settings:** Atoll sets the disable-library-validation entitlement [V], for reasons not recorded in its source [I]. DropNotch's design doesn't need it. The adapter framework is never loaded into our process; `/usr/bin/perl` loads it, and that binary is Apple-signed with no hardened runtime and no entitlements [V: `codesign -dvvv /usr/bin/perl` on macOS 27.0.1]. Entitlements apply only to the executable that carries them; frameworks inherit them from their host executable [V: https://developer.apple.com/documentation/security/hardened-runtime]. A local test confirmed that a hardened-runtime host without the exception can't load an ad-hoc library itself, but a Perl process it spawns can [V: security-auditor local test, macOS 27.0.1, dummy library, not the real adapter]. Don't add the exception. If the framework is ever loaded into DropNotch itself, re-evaluate and record it in DECISIONS.md.
- **Remaining risks of the Perl route** [I unless tagged]: anything at the framework path runs as the user, so check the bundle's code signature before launching Perl and install only to /Applications; pass a minimal environment and argument arrays, never a shell or user text (the script treats any `--` argument as an option [V: upstream script]); run the adapter's `test` command at most once per macOS build, because it can briefly create a fake now-playing entry [V: upstream README]; use the stream without artwork and never log its output. Re-check `codesign -dvvv /usr/bin/perl` on each macOS release, because the design depends on Perl staying outside the hardened runtime.
- **Licence:** ungive/mediaremote-adapter is BSD-3-Clause, copyright Jonas van den Berg and contributors [V: https://github.com/ungive/mediaremote-adapter/blob/master/LICENSE]. It is compatible with MIT DropNotch, provided the notice ships with the app [I: standard BSD-3 terms]. Build the framework from upstream source at a pinned commit. Never copy Atoll's bundled binary, which has no licence file in Atoll's tree [V].
- **Mitigation:** MVP uses public scripting for Apple Music and Spotify only (D2). A MediaRemote provider is an optional v0.2 module with: our own check result cached per macOS build, a visible "unavailable on this macOS" state instead of empty UI, and a `dependency-manager` licence review.

### 1.2 AirPods and Bluetooth accessory battery

- **What:** device, per-bud and case battery for AirPods.
- **Atoll's sources:** IORegistry properties on a Bluetooth HID service, parsing `pmset` and `system_profiler` output in child processes, and the CoreBluetooth Battery Service [V: research/atoll-system-shell.md A3]. The property shapes and output formats are undocumented [V]. AirPods probably don't expose the standard Battery Service to third-party apps [I].
- **Likelihood of breaking:** high: four undocumented sources, and the per-bud data depends on the device generation [V].
- **Mitigation:** later priority. When built, use one source behind `BluetoothBatteryProvider` and hide the figure when it returns nothing. No subprocess parsing in the app. Connection state and the connect animation use IOBluetooth's documented registration [V: API exists] and are v0.2.

### 1.3 Drawing on the lock screen

- **What:** full-screen now playing and widgets (battery, audio battery, AQI, temperature) on the lock screen.
- **Facts:** windows using only public window levels and collection behaviour don't appear above the lock screen. Atoll's own changelog says its public-API HUDs sit below the lock shield [V]. Atoll draws over the lock screen by handing windows to a private Space through the SkyLightWindow package, pinned to a branch [V]. For full-screen artwork it rewrites the user's wallpaper store and stops the wallpaper processes with a signal [V].
- **Likelihood of breaking:** high for both routes [V: Atoll's risk table]. The wallpaper route can also damage the user's wallpaper settings if backup or restore fails [I].
- **Mitigation:** no lock-screen features in MVP or v0.2 (D3). If built later: the SkyLight route only, opt-in, behind a protocol, with `security-auditor` and `dependency-manager` reviews. Never the wallpaper route. No lock notification is in NSWorkspace's documented notifications [V: https://developer.apple.com/documentation/appkit/nsworkspace]; absence can't be proven [I]; lock detection is checked in Phase 2. Atoll uses undocumented lock notifications plus a 500 ms poll while locked [V], and the poll breaks our energy rule.

### 1.4 Other private routes we are choosing not to use

| Route | Used by Atoll for | Risk | Status |
|---|---|---|---|
| Private window-server Space wrapper | Notch above everything [V] | High [V] | Not used; public collection behaviour first, and check on device |
| Stopping the system OSD helper process | Replacing volume/brightness HUDs [V] | High [V] | Skip |
| Private CoreBrightness, IORegistry backlight | Brightness, keyboard backlight [V] | High [V] | Skip |
| Undocumented Focus files + Full Disk Access | Focus indicator [V] | High [V] | Skip |
| `log stream` of system daemons | AirPods listening mode [V] | High; privacy [V] | Skip |
| Accessibility scraping of the Clock app | Timer mirror [V] | High [V] | Skip |

## 2. Permission UX

Principle: ask for each permission when its feature is first enabled, explain why on our own screen before macOS asks, and degrade gracefully when the user says no (CLAUDE.md).

| Permission | Needed by | When we ask | If denied | Risk |
|---|---|---|---|---|
| Automation (Apple Events) for Music / Spotify | Now Playing controls (MVP) | First time the user plays with that player while Now Playing is on | Show track info if notifications still arrive; hide controls with a "Allow in System Settings" link [I] | Medium. One prompt per app; the user may not connect the prompt to the feature [I]. |
| Pasteboard access | Clipboard history (MVP) | When clipboard history is first enabled | Feature stays off with an explanation | Medium. From macOS 15.4 the general pasteboard asks the user on programmatic access; a paste the user starts is always allowed [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]. Whether reading only `changeCount` or `types` counts as access is undocumented [I: device probe, D7]. If the user picks Always Deny, reads fail silently, so read `accessBehavior` (15.4+, behind `#available`) to show a blocked state. This could make background history noisy or impossible. Check on the current macOS early in Phase 2. |
| Files and folders (Desktop, Documents, Downloads) | File tray, if it reads files by reference | First drop from a protected folder | Fall back to copying from the drag (D6) | Low to medium. Desktop, Documents and Downloads prompt on first access without implied consent [V: https://developer.apple.com/documentation/bundleresources/information-property-list/nsdesktopfolderusagedescription]; behaviour for unsandboxed apps is a device check [I]. |
| Audio capture | Real waveform (v0.2) | Waveform setting enabled | Decorative waveform | Medium. Tap creation (`AudioHardwareCreateProcessTap`) is macOS 14.2+ [V: https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:)], and the first recording from a tap prompts for permission [V: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps]; Atoll saw side effects on Bluetooth output [V]. |
| Calendars | Calendar panel (v0.2) | Calendar panel chosen | Notes panel stays | Low |
| Bluetooth | Connect animation (v0.2) | Module enabled | Module off | Low |
| Location | Weather/AQI (later) | Module enabled. Atoll asks at launch by default [V], which we won't copy. | Manual city entry [I] | Low |
| Accessibility | Nothing in MVP | — | — | Avoided on purpose: it is a powerful permission users are right to distrust. |

Testing note: permission prompts behave differently for ad-hoc-signed builds than for Developer ID builds, because macOS may tie privacy grants to code identity [I: Apple documents resetting grants by bundle ID only, https://developer.apple.com/documentation/bundleresources/information-property-list/nsdesktopfolderusagedescription; confirm on device]. A rebuild may re-prompt or lose grants during development.

## 3. Distribution outside the Mac App Store

DropNotch can't go on the Mac App Store because it plans private APIs (CLAUDE.md) [V].

| Topic | Risk | Plan |
|---|---|---|
| **Developer ID signing** | No Apple Developer account yet [V: CLAUDE.md]. Without Developer ID and notarisation, Gatekeeper warns that macOS can't verify the app and users have to override it in System Settings [V: https://support.apple.com/en-us/102445]. This is a real adoption barrier and teaches users a bad habit. | Until there is an account: GitHub pre-releases only, labelled as developer builds, with written override steps. Public 1.0 waits for Developer ID (D10). |
| **Notarisation** | Needs Developer ID, the hardened runtime and a secure timestamp [V: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution]. Library-validation exceptions draw extra Gatekeeper checks [V: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation]; the adapter doesn't need one (§1.1). Whether each nested framework must carry our Developer ID signature isn't stated; check the notarytool log [I]. | Hardened runtime on from the start. No exceptions in MVP. Notarise in CI with credentials kept in CI secrets (CLAUDE.md). |
| **App Sandbox** | Apple requires the sandbox for Mac App Store distribution [V: https://developer.apple.com/documentation/security/app-sandbox]; whether Developer ID apps can skip it, and how hard private APIs and Apple Events are inside it, is our reading [I]. Atoll is unsandboxed [V]. Without the sandbox, a bug has a bigger blast radius. | D4. Recommendation: unsandboxed plus hardened runtime, with `security-auditor` on every change to the tray, clipboard or subprocesses. |
| **DMG packaging** | macOS checks downloaded software before first open [V: https://support.apple.com/en-us/102445]; whether a DMG gets the same check is a device test [I]. | Signed, notarised DMG built in CI (cicd-agent), once Developer ID exists. |
| **Sparkle updates** | An update feed is a supply-chain target. Atoll serves appcasts from its repo's raw file host on the main branch [V] and turns off App Transport Security app-wide [V]. Sparkle should only deliver EdDSA-signed updates [V: Atoll's appcasts are signed]. | v0.2: Sparkle with an exact version pin, licence recorded in DECISIONS.md, EdDSA private key in the keychain or CI secrets only, appcast published with GitHub Releases, ATS left on. |
| **Licence lineage** | Atoll's NOTICE says it derives from boring.notch, and it doesn't credit several bundled sources [V]. Copying any of it, even indirectly, would bring GPL obligations and unclear third-party terms. | Clean-room rule (CLAUDE.md). Only `reference-analyst` reads `./reference/`. Implementation uses `docs/research/` and Apple documentation. |

## 4. Product risks

| Risk | Note |
|---|---|
| Canopy covers the same surface with polish and a paid team [V: changelog cadence] | Compete on productivity (tray, clipboard, notes), openness and energy, not on lock-screen visuals. |
| Energy claims nobody can check | Canopy claims about 20% CPU while playing and 0 MB idle; neither is verified [V: canopy.md]. Measure ours with Instruments before stating any figure. A diagnostics panel (v0.2) lets users check. |
| Hover at the very top pixel row is unreliable | Atoll needed a polling fallback for this [V]. Our tracking-area plan is unproven [I]. Check on a real notched Mac first thing in Phase 2. |
| Maintenance on each macOS release | Canopy's changelog shows ongoing fixes for browser playback and Bluetooth audio [V]. Keep a manual test checklist per macOS release: Music, Spotify, a browser player, AirPods connected. |
