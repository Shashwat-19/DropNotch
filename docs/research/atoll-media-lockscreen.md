# Atoll: media and lock screen features (clean-room notes)

> Tagging rule: a verified or inferred tag on a heading or a lead-in line applies to every bullet under it, until another tag overrides it. Lines under "Gaps", "Method" or "What I did not check" describe the analysis itself, not the app.

- Source: Atoll (GPL-3.0), tree at `reference/atoll`, tag `v2.3.3-alpha.4`, commit `2e15e5f`. Version file reads 2.3.3.
- Written by the reference-analyst from reading source, file listings, the ReadMe and CHANGELOG. Nothing was compiled, run, disassembled or decompiled. Binaries (the third-party adapter framework and the compiled test helper) were only listed, not inspected.
- Paths are relative to `reference/atoll/` unless shown as absolute.
- No code is reproduced. Private Apple symbols are described by role, not by name. Atoll's own type, function, property and key names are also described by role. File paths are kept as citations, because they are needed to check claims.
- Revision note: this version replaces identifiers and quoted strings from Atoll's source with plain descriptions, and links public Apple APIs to their documentation. The linked Apple pages were checked for existence only (the page titles resolved). Their body text was not read in this pass, so the links are for lookup, not evidence for the behaviour claims.

**Tags.** Every claim is marked `[verified]` (seen in the source, ReadMe or CHANGELOG, with a path) or `[inferred]` (my reasoning, or public background not confirmed in Atoll's tree).

**API labels.** `public` means a documented Apple SDK API. `private` means an undocumented or private framework, symbol, key or mechanism. `third-party` means a non-Apple package or service.

---

## 0. Feature map at a glance

| # | Feature | Main mechanism | Public / private |
|---|---|---|---|
| 1 | Generic Now Playing (any app) | Helper process streaming now-playing JSON, plus in-process command calls into the private now-playing framework | private |
| 2 | Apple Music source | Distributed notification plus AppleScript | public (scripting) |
| 3 | Spotify source | Distributed notification plus AppleScript, Web API for metadata and liking a song | public, plus undocumented endpoints for Canvas |
| 4 | YouTube Music, Cider, TIDAL, Amazon Music | Local companion APIs, Accessibility, or filtered Now Playing | third-party / private / public AX |
| 5 | Restriction check (macOS 15.4+) | Helper run in a test mode, exit status read | private |
| 6 | Artwork | Stream artwork, iTunes Search, MusicKit animated artwork | public + undocumented Apple video URLs |
| 7 | Seek, shuffle, repeat, favourite | Mixed (private now-playing framework, AppleScript, AX, Web API) | mixed |
| 8 | Real-time waveform scrubber and spectrum visualiser | Core Audio process tap | public (macOS 14.2+ Core Audio) |
| 9 | Lyrics (synced, pinned, sweep highlight) | LRCLIB public API, NetEase (undocumented), local rendering | third-party / undocumented |
| 10 | Media keys | Session-level event tap | public (needs Accessibility) |
| 11 | Lock-screen detection | Distributed lock notifications, session dictionary poll | undocumented notifications and session flag |
| 12 | Lock-screen music panel and other lock widgets | Borderless window at shielding level, handed to a third-party private-space delegation | public window APIs + third-party private-space package |
| 13 | Full-screen artwork on lock and desktop | Desktop-level windows, rewriting the wallpaper store, signalling the wallpaper agent | private/undocumented |
| 14 | Lock-screen battery, weather, timers, Bluetooth battery | IOPS (public), Open-Meteo, CoreLocation, IORegistry keys (private) | mixed |

---

## 1. Generic Now Playing (any app)

**What it does.** Shows title, artist, album, artwork, duration, elapsed position, playing state, shuffle and repeat for whichever app the Mac's system Now Playing session reports. Sends play, pause, toggle, next, previous, seek, shuffle and repeat commands to that app. Keeps an extrapolated playback position between updates. [verified: `DynamicIsland/MediaControllers/NowPlayingController.swift`]

**How the data arrives (two paths).**

1. **Stream path (helper process).** Atoll runs a bundled script through the system's Perl interpreter, which streams now-playing updates to the app as JSON over a pipe. [verified: `NowPlayingController.swift`; `mediaremote-adapter/mediaremote-adapter.pl`]
2. **Command path (in-process).** Play, pause, toggle, next, previous, seek, shuffle and repeat are sent by looking up functions in the system's private now-playing framework at runtime (public `CFBundle` function-pointer lookup) and calling them directly. [verified: `NowPlayingController.swift`, initializer and the command methods]

**Stream semantics worth copying in concept.** [verified: `NowPlayingController.swift`, the update handler and its comments]
- Updates are diffs by default: an absent field means no change, while an explicit empty position means there is no position. The decoder keeps that distinction.
- Position and its sample timestamp are a matched pair. Adopting a fresh position with an old anchor makes the estimate run ahead.
- Some senders publish once per track and go silent. The code re-anchors on play/pause transitions instead of trusting the sender to keep publishing.
- The stream uses microsecond time fields. The ISO-8601 timestamp is truncated to whole seconds and was biasing lyric and progress timing forward by up to a second. CHANGELOG records the fix. [verified: `CHANGELOG.md` line 133]

**Adapter script details.** The script header carries a BSD-3-Clause notice from its author. Its help describes subcommands for streaming, one-shot reads, transport commands, seek, shuffle, repeat, playback speed and a self-test. Parameters reach the framework through environment variables. [verified: `mediaremote-adapter/mediaremote-adapter.pl`, header and help text]

**Frameworks and APIs.**
- `/usr/bin/perl` (Apple-shipped interpreter, public binary): runs the script. [verified: `NowPlayingController.swift`]
- Vendored third-party adapter framework (built from the adapter project; the framework binary was not inspected). It exports functions that wrap the private now-playing framework. [verified: the file layout (two copies of the bundle, see Files); wrapper behaviour verified from the script]
- Private: the system's private now-playing framework, used directly for commands. [verified: `NowPlayingController.swift`]
- Public: `Process`, `Pipe`, `JSONDecoder`, `Combine`. [verified]

**Permissions and entitlements.**
- No Accessibility, Screen Recording or Automation permission is needed for the stream path. [inferred: none is requested for this path in the code]
- Entitlement `disable-library-validation` is set. [verified: `DynamicIsland/DynamicIsland.entitlements`] Apple's page for it: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_cs_disable-library-validation. Its exact necessity in Atoll is [inferred]: it lets the app load a framework it did not sign itself into the process.
- Sandbox: the entitlements file has no app-sandbox key, so the app is not sandboxed. [verified: same file] This matters for the Apple Events exception below.

**Files.**
- `DynamicIsland/MediaControllers/NowPlayingController.swift`
- `DynamicIsland/MediaControllers/MediaControllerProtocol.swift`
- `mediaremote-adapter/mediaremote-adapter.pl`
- `Frameworks/MediaRemoteAdapter.framework/` and `mediaremote-adapter/MediaRemoteAdapter.framework/` (two copies of the same bundle)
- `DynamicIslandTests/NowPlayingPayloadTests.swift` (payload decoding tests)

**Breakage risk on macOS updates: HIGH.** Why:
- The stream and commands depend on private now-playing symbols. [verified: code]
- macOS 15.4 restricted the private now-playing framework for apps without the right entitlement. Atoll's workaround is to route through an Apple-signed interpreter. [verified that Atoll does this and checks for it; the reason being the Apple-signed interpreter is [inferred] from public community knowledge, not from Atoll's source]
- The command path is not routed through the helper. Whether it still works on 15.4+ is not shown in the tree. [inferred: it is not tested in code, and the code does not say]

---

## 2. Now Playing restriction handling (macOS 15.4+)

**What it does.** At launch, Atoll runs the helper in a test mode with a bundled helper binary and reads the exit status. If the test reports the restricted state (see Details), Atoll never creates the Now Playing controller. A user preference for Now Playing is silently replaced with the Apple Music controller. If the check itself fails (missing files, timeout, script error), Atoll assumes Now Playing is available. [verified: `DynamicIsland/helpers/MediaChecker.swift`; `DynamicIsland/managers/MusicManager.swift`, around the deprecation task and the controller-creation and preference-driven selection routines]

**Details.**
- The check has a short timeout. [verified: `MediaChecker.swift`]
- The check tells apart three outcomes (restricted, available, error) and treats an error as available. The exact signalling isn't recorded here. [verified: `MediaChecker.swift`]
- The helper is a compiled binary committed in the app bundle's helpers folder. Its source is not in the tree, so what it does is [inferred]: a small client the framework's test entry point runs to see whether the private framework returns data.
- The check runs at startup on every launch; there is no cached result. [verified: `MusicManager.swift`, at initialisation]

**Frameworks and APIs.** Private now-playing framework (through the adapter). Public `Process`, `Pipe`, `Task` groups. [verified]

**Permissions.** None. [inferred from code]

**Files.**
- `DynamicIsland/helpers/MediaChecker.swift`
- `DynamicIsland/managers/MusicManager.swift`
- The compiled test helper in the app bundle's helpers folder (binary, not inspected)
- `mediaremote-adapter/mediaremote-adapter.pl` (the test mode)

**Breakage risk: HIGH.** The check depends on the private framework's test behaviour and on a helper binary whose source is not available in the tree. Its failure mode is conservative (it defaults to "available"), so a future macOS may leave Now Playing on but silent instead of cleanly off. [inferred]

**Gaps.** The tree does not say which macOS versions were tested, or what the test does on 15.4 specifically. Atoll's CHANGELOG has no entry on 15.4 for this. [verified: searched `CHANGELOG.md`]

---

## 3. Per-source support

Atoll exposes a source picker. Each source is a controller type implementing one protocol. [verified: `MusicManager.swift`, the controller-creation routine and the controller-type enumeration]

### 3a. Apple Music

**What it does.** Track info, artwork, play/pause/next/previous, seek, shuffle, repeat, favourite (via Music's own library property), AirPlay device volume.

**Mechanism.**
- Change notification: the public distributed-notification centre, subscribed to the Music player-info notification name. The notification name is undocumented. [verified: `DynamicIsland/MediaControllers/AppleMusicController.swift`, the observer setup routine; status of the name: [inferred] undocumented]
- Reads and writes: AppleScript sent to Music through `NSAppleScript` on a detached task. The script reads player state, track name, artist, album, position, duration, shuffle, repeat and raw artwork in one call. Commands are plain Music verbs. [verified: `AppleMusicController.swift`, the read routine and the command routine; `DynamicIsland/helpers/AppleScriptHelper.swift`]
- Artwork fallback: the public iTunes Search web service, then the high-resolution image from the returned URL. Result cached by track key. [verified: `AppleMusicController.swift`, artwork fetch]
- Favourite: AppleScript reads and writes a library property on the current track. It only runs when Music is already running, so it never launches the app. [verified: `DynamicIsland/MediaControllers/AppleMusicController.swift`, the favourite-handling type]
- AirPlay volume: AppleScript commands through a serial commit queue, throttled from a slider. [verified: `DynamicIsland/managers/AppleMusicAirPlayManager.swift`, comments]

**Permissions.** Automation (Apple Events) consent for Music, prompted on first use. Usage text is set in the project, not Info.plist. [verified: `DynamicIsland.xcodeproj/project.pbxproj` (the Apple Events usage-description key, set as a build setting in two configurations); `DynamicIsland/DynamicIsland.entitlements` lists the Apple Events automation entitlement and a temporary exception for Music]
- Note: the temporary exception is a sandbox-only mechanism. Because the app is not sandboxed, its effect is [inferred] to be nil; the automation entitlement carries the real meaning.

**Files.**
- `DynamicIsland/MediaControllers/AppleMusicController.swift` (462 lines)
- `DynamicIsland/helpers/AppleScriptHelper.swift`
- `DynamicIsland/managers/AppleMusicAirPlayManager.swift`

**Breakage risk: LOW-MEDIUM.** AppleScript dictionaries for Music are public and stable, but the notification name and the script responses are undocumented. Automation consent can be revoked by the user. Scripting a closed app launches it, which Atoll avoids by checking first.

### 3b. Spotify

**What it does.** Track info, artwork, controls, seek, shuffle/repeat (via the Now Playing stream), Spotify Canvas looping video (artwork-as-video), artist metadata, and a like action for the current song.

**Mechanism.**
- Change notification: distributed notification from Spotify's playback-state change. Undocumented name. [verified: `DynamicIsland/MediaControllers/SpotifyController.swift`, the observer setup routine]
- Reads and writes: AppleScript on Spotify. [verified: `SpotifyController.swift`, around the AppleScript execution; `NSAppleEventDescriptor` usage]
- Liking a song: the official Spotify Web API with OAuth 2.0 PKCE; tokens stored in the Keychain as generic passwords with accessible-after-first-unlock. [verified: `CHANGELOG.md` line 33; `DynamicIsland/managers/Spotify/SpotifyTokenStore.swift`; `DynamicIsland/managers/Spotify/SpotifyOAuthService.swift`]
- Track metadata: Web API track endpoint with bearer token. [verified: `SpotifyController.swift` around the Web API URL]
- Spotify Canvas (looping video behind artwork): **undocumented**. It depends on an undocumented, cookie-gated path that uses configuration hosted by a third party, outside Spotify's public terms. [verified: `DynamicIsland/managers/SpotifyAuthManager.swift`; `SpotifyController.swift`]
  - The web-session cookie is stored in the app's preferences, not in the Keychain. [verified: `DynamicIsland/models/Constants.swift` (the preference key for the cookie); `SpotifyAuthManager.swift` storage] This is a credential in plain preferences.
  - Using a web-player token and an internal endpoint is outside Spotify's public terms [inferred].
- Rendering: the Canvas video is shown through an AV player layer inside a looping video view in a desktop-level window. [verified: `DynamicIsland/managers/FullScreenArtworkWindowManager.swift`]

**Permissions.** Automation for Spotify (the app's Apple Events exception list includes Spotify's bundle id). [verified: `DynamicIsland/DynamicIsland.entitlements`]. Network access (no special entitlement, sandbox is off).

**Files.**
- `DynamicIsland/MediaControllers/SpotifyController.swift` (903 lines)
- `DynamicIsland/managers/SpotifyAuthManager.swift` (Canvas token path)
- `DynamicIsland/managers/Spotify/` (OAuth, Keychain token store, Web API library)

**Breakage risk.** Notification and AppleScript: MEDIUM (Spotify changes its scripting dictionary occasionally). Canvas path: HIGH (undocumented endpoints, token scheme, third-party secrets file, ToS exposure). Web API path: LOW.

### 3c. YouTube Music (companion desktop app)

**What it does.** Track info, controls, favourite, lyrics context, through a companion desktop app. [verified: `DynamicIsland/MediaControllers/YouTubeMusicController.swift`, `YouTube Music Controller/` folder]

**Mechanism.** The companion app exposes a local HTTP API on localhost, plus a WebSocket for live updates. Requests carry a bearer token. Auto-switches to this source when the companion launches or quits. [verified: `YouTube Music Controller/YouTubeMusicModels.swift` (localhost base URL), `YouTubeMusicNetworking.swift` (WebSocket task, bearer header), `YouTubeMusicAuthentication.swift`; `DynamicIsland/managers/MusicManager.swift` (launch and terminate observers)]

**Permissions.** None beyond local networking. [inferred]

**Breakage risk: MEDIUM.** Depends on a third-party app's local API. Stable if its maintainers keep it; no Apple dependency.

### 3d. Cider

**What it does.** Track info, controls, favourite (Cider's own rating API), through a local API. Token stored in the Keychain. [verified: `DynamicIsland/MediaControllers/CiderController.swift` (localhost and default port comments; `URLSession`); `CiderTokenStore.swift` (Keychain generic-password items, with migration from preferences)]

**Breakage risk: MEDIUM.** Depends on Cider's documented local API (Atoll cites Cider's own docs in a code comment). [verified: `CiderController.swift` comment]

### 3e. TIDAL

**What it does.** Track info through the Now Playing stream, filtered to TIDAL's own player process. Shuffle, repeat and favourite are done by driving TIDAL's own menu items through Accessibility, because TIDAL does not register those commands. Favourite is read-only for TIDAL. [verified: `DynamicIsland/MediaControllers/TidalController.swift` (Accessibility calls, `AXIsProcessTrusted` check); `NowPlayingController.swift` comments on TIDAL shuffle and favourite; `CHANGELOG.md` line 25]

**Permissions.** Accessibility (control of another app's UI). [verified: `TidalController.swift`]

**Breakage risk: HIGH.** Depends on TIDAL's menu titles and UI tree. Any TIDAL update can break it. Uses Accessibility messaging timeouts. [verified: `TidalController.swift`, `AXUIElementSetMessagingTimeout`]

### 3f. Amazon Music

**What it does.** Track info and controls through the Now Playing stream, filtered to Amazon Music. When another app owns Now Playing, state goes idle so stale metadata is not shown. [verified: `DynamicIsland/MediaControllers/AmazonMusicController.swift`, class comments and the shared filtered base type]

**Breakage risk: HIGH** (inherits Section 1). The class also loads the private now-playing command functions itself. [verified]

### 3g. Filtering base class (shared by Amazon Music, TIDAL, Cider)

A shared filtering base type is defined in `DynamicIsland/MediaControllers/AmazonMusicController.swift` and subclassed by the TIDAL and Cider controllers. [verified] It reuses the same adapter stream and filters by source bundle id. [verified]

---

## 4. Track info, artwork, controls, seek

- **Artwork (generic).** Base64 artwork inside the stream payload, decoded to image data. Diff updates keep the previous artwork unless the payload says otherwise. [verified: `NowPlayingController.swift`]
- **Artwork (Apple Music fallback).** iTunes Search web service, returned at a larger size. [verified: `AppleMusicController.swift`]
- **Artwork (animated, Apple Music).** Uses MusicKit catalogue search and a catalogue request for the track's editorial video. A fallback parses the response for the video stream address, which is undocumented and can change shape. [verified: `DynamicIsland/managers/AnimatedArtworkManager.swift`] Token errors are retried with exponential back-off up to a cap. [verified: same file]
- **Seek.** Generic: sends an elapsed-time value through the private now-playing seek routine. Apple Music: AppleScript sets player position. [verified: `NowPlayingController.swift`, `AppleMusicController.swift`]
- **Shuffle and repeat.** Generic: private now-playing setters, with the controller cycling repeat modes locally. Apple Music: AppleScript. [verified]
- **Gestures.** The ReadMe says horizontal trackpad gestures on the music pane skip tracks or seek by ten seconds. [verified: `ReadMe.md` line 90. The gesture implementation was not traced in this pass; a likely starting point is the pan-gesture file `DynamicIsland/extensions/PanGesture.swift`, which is [inferred] to be the source]

**Files.** `DynamicIsland/managers/MusicManager.swift` (central state, controller switching, lyrics orchestration; ~1,800 lines), the per-source controllers above, `DynamicIsland/managers/AnimatedArtworkManager.swift`.

**Breakage risk.** Seek and shuffle/repeat through the private now-playing framework: HIGH. Scripting and public web APIs: LOW-MEDIUM.

---

## 5. Waveform scrubber and spectrum visualiser

**What it does.**
- A real-time waveform scrubber and a bar spectrum that react to the audio actually playing from the chosen music app. [verified: `DynamicIsland/components/Music/RealTimeWaveformScrubberView.swift`, `DynamicIsland/audio/RealTimeAudioSpectrum.swift`, `DynamicIsland/components/Music/MusicVisualizer.swift`]
- A per-app volume mixer also sits on the same tap infrastructure. [verified: `CHANGELOG.md` line 12]

**Frameworks and APIs.**
- Public: Core Audio process tap (`CATapDescription` and an aggregate device to read the tapped audio) — available from macOS 14.2. [verified: `DynamicIsland/audio/AudioTap.swift` (create/destroy calls, comments); public API names are Apple's]
- Public: the Accelerate framework's vDSP biquad filters run band-splitting on the tapped samples, inside a small C++ processor behind an Objective-C++ bridge. [verified: `DynamicIsland/audio/AudioProcessor.hpp` and `AudioProcessor.cpp` (vDSP biquad calls, `Accelerate` import); `AudioBridge.mm`, `AudioBridge.h`]
- Not used: Metal. There is a shader file in the tree (`DynamicIsland/metal/visualizer.metal`), but no Swift code references Metal or `MTKView`. [verified by grep; [inferred] the shader is dead code]

**How the tap chooses targets.** It enumerates Core Audio process objects, matches them to a fixed list of music apps by bundle id (including helper processes, such as TIDAL's player), and taps those. [verified: `AudioTap.swift` around the process enumeration and the fixed bundle-id list]

**Bluetooth caveat (important).** The source records that process-tapping Spotify into the private aggregate device disturbs the system Now Playing and AVRCP route while a Bluetooth output is active. On AirPods the pause gesture then falls through to Siri. Atoll skips tapping Spotify while Bluetooth output is active. [verified: `AudioTap.swift` comment near the Bluetooth check; `CHANGELOG.md` line 177 describes the regression fix]

**Permissions.**
- Audio capture consent, declared with the audio-capture usage-description Info.plist key (`NSAudioCaptureUsageDescription`). [verified: `DynamicIsland/Info.plist`] Whether Apple documents this key publicly was not checked in this pass [inferred: it is Apple-defined].
- Nothing else.

**Starts and stops.** Starts only when the user enables the waveform setting, and stops when disabled. [verified: `DynamicIsland/DynamicIslandApp.swift` around the setting observers]

**Timers (energy).**
- Spectrum: 30 fps timer. [verified: `RealTimeAudioSpectrum.swift`]
- Waveform scrubber: 60 fps timer, run-loop common modes. [verified: `RealTimeWaveformScrubberView.swift`]
- Music visualiser: 0.3 s timer. [verified: `MusicVisualizer.swift`]
- These run while the relevant view is visible. The tree does not show a power-based throttle. [inferred]

**Breakage risk: MEDIUM.** The process-tap API is public and new, so it should be stable within the 14.2+ range, but the aggregate-device and route side effects are the kind of behaviour that changes between releases. The Bluetooth workaround is a symptom of that coupling.

---

## 6. Lyrics

**What it does.** Synced lyrics panel beside the notch and the lock-screen player, with a sweep highlight across the current line, instrumental-break markers, auto-scroll, a pinned mode that keeps the current line visible under the closed notch, and lyrics on the full-screen artwork overlay. [verified: `CHANGELOG.md` lines 11, 26-29; `DynamicIsland/components/Music/SyncedLyricsList.swift`, `PinnedLyricsView.swift`, `DynamicIsland/components/LockScreen/LyricSweep.swift` (sweep, instrumental notes), `DynamicIsland/managers/FullScreenArtworkWindowManager.swift` (lyrics overlay, ~lines 222 and 1337)]

**Sources.**
1. LRCLIB search (public, community-run, no key). The search request is built from track title, artist and album. [verified: `DynamicIsland/managers/MusicManager.swift`, search URL around line 1840]
2. NetEase Cloud Music search and lyric endpoints (undocumented, used as a fallback when LRCLIB has nothing). [verified: `DynamicIsland/managers/NetEaseLyrics.swift` (two endpoint hosts in the file); `MusicManager.swift` around the fallback call]
- The sources are only queried when the lyrics setting is on. The code stops before the request if it is off, after a fix for sending title and artist to LRCLIB while lyrics were disabled. [verified: `MusicManager.swift`, comment in the lyrics-preparation routine]
- Lyric metadata ordering has a check script and tests. [verified: `scripts/check_lyrics_metadata_order.rb`; `DynamicIslandTests/LyricsMetadataTests.swift`, `UnsyncedLyricsTests.swift`, `PinnedLyricsTests.swift`, `NetEaseLyricsTests.swift`]

**Frameworks.** Public: `URLSession`, SwiftUI, and the Defaults package for preferences. Undocumented: NetEase endpoints. [verified]

**Permissions.** Network only. [inferred]

**Breakage risk.** LRCLIB: LOW (public API, but a community service with no SLA). NetEase: HIGH (undocumented, region-specific, terms-of-service exposure). Sweep rendering: LOW.

---

## 7. Media keys (and why they matter to media)

**What it does.** Intercepts the system's media keys (play/pause, next, previous and related keys) and volume/brightness keys so that Atoll can draw its own HUD and act on the key. Can also consume the mute key. [verified: `DynamicIsland/managers/MediaKeyInterceptor.swift`, key-type constants and handling; `DynamicIsland/managers/SystemChangesObserver.swift` (start, configure, stop)]

**Mechanism.** Atoll intercepts media and volume/brightness keys through a system-level event tap, which needs Accessibility, and it recovers if the system disables the tap. [verified: `MediaKeyInterceptor.swift`]

**Frameworks.** Public: `CGEvent` tap APIs, `AXIsProcessTrusted`, `NSEvent` monitors. Legacy key-type constants come from the public event header. [verified]

**Permissions.** Accessibility. [verified]

**Tests.** `DynamicIslandTests/MediaKeyTapRetryPolicyTests.swift`. [verified]

**Breakage risk: LOW-MEDIUM.** The event-tap API is public, but a default tap that consumes keys is a system-level behaviour that macOS may restrict further. The removal of the key from the system HUD is version-dependent. [inferred; CHANGELOG line 140 records a macOS 26 change to the native volume HUD drawing]

---

## 8. Lock-screen detection

**What it does.** Knows when the Mac is locked and unlocked, and shows or hides lock-screen widgets accordingly. Re-presents the panel if the system removes it while still locked. [verified: `DynamicIsland/managers/LockScreenManager.swift`]

**Mechanism.**
- Distributed notifications for lock and unlock events, both undocumented system notifications. [verified: `LockScreenManager.swift`, the observer setup routine; status [inferred] undocumented]
- Workspace session-active notification as an earlier unlock signal. Public. [verified: same file]
- Polling while locked: every 500 ms, the code checks the session state (public `CGSessionCopyCurrentDictionary` plus an undocumented lock flag) to catch unlocks that the notifications miss. [verified: `LockScreenManager.swift`, the polling routine and the lock-flag reader]
- Power-key monitoring: local and global system-defined event monitors look for the power-key subtype, to play the fingerprint animation for Touch ID presses. [verified: `LockScreenManager.swift`, the observer setup routine]

**Permissions.** None for notifications and session dictionary. Global monitors for system-defined events may need Input Monitoring or Accessibility on some versions. [inferred]

**Breakage risk: MEDIUM.** The notifications and the flag are undocumented, though widely used. The 500 ms poll is an energy cost and is a fallback for the notification latency. [inferred on latency reason; verified on the code comment]

**Files.** `DynamicIsland/managers/LockScreenManager.swift` (519 lines), `DynamicIsland/managers/LockScreenDisplayContextProvider.swift`.

---

## 9. Lock-screen music panel and other lock widgets (window mechanism)

**What it does.** A music player (artwork, title, artist, transport, seek bar, volume capsule, output picker, lyrics beside the artwork, source badge, right-click menu) drawn on the lock screen. Also: weather, timer, reminder, calendar row, a fingerprint or lock live activity, and a battery indicator. [verified: `DynamicIsland/components/LockScreen/LockScreenMusicPanel.swift` (2,031 lines), `LockScreenWeatherWidget.swift`, `LockScreenTimerWidget.swift`, `LockScreenReminderWidget.swift`, `LockScreenCalendarEventRow.swift`, `LockScreenLiveActivity.swift`; `CHANGELOG.md` lines 21-29, 106]

**Window mechanism.** [verified: `DynamicIsland/managers/LockScreenPanelManager.swift`] A borderless, non-activating, transparent window at the public shielding level (see [`CGShieldingWindowLevel`](https://developer.apple.com/documentation/coregraphics/cgshieldingwindowlevel()) and [`NSWindow.Level`](https://developer.apple.com/documentation/appkit/nswindow/level)), allowed on all Spaces and over full-screen apps ([`NSWindow.CollectionBehavior`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior)), hosting SwiftUI content. That this is the level the lock screen uses is [inferred]. On its own this isn't enough to appear over the lock screen; visibility there comes from the private-space delegation below. The window can be hidden from screen capture through [`NSWindow.sharingType`](https://developer.apple.com/documentation/appkit/nswindow/sharingtype) [verified: `DynamicIsland/helpers/ScreenCaptureVisibilityManager.swift`; [inferred] that modern ScreenCaptureKit honours it].

**The private-space delegation (third-party package).**
- Atoll depends on a third-party Swift package named `SkyLightWindow`, pinned to a **branch** (`main`), not a version. [verified: `DynamicIsland.xcodeproj/project.pbxproj` package reference; `ReadMe.md` line 114 credits it for lock-screen widget rendering]
- Atoll imports it in about 13 files and hands every overlay window (lock panels, HUDs, full-screen artwork, extension widgets) to the package through one of its entry points. [verified: grep in `DynamicIsland/managers/`]
- The package source is not in `reference/atoll` (it is fetched by Swift Package Manager), so its internals are [inferred]: it wraps undocumented window-server and CoreGraphics Services calls to move the window into a private space above the lock shield.
- Atoll also has its own in-house private-space wrapper (`DynamicIsland/private/CGSSpace.swift`). It binds undocumented window-server functions by their C symbol names, using a Swift underscore attribute. It is used for the notch at maximum level. [verified: `CGSSpace.swift`; `DynamicIsland/managers/NotchSpaceManager.swift` around line 32]

**What the lock screen allows (limits).**
- Windows drawn with only the public level and collection behaviour do **not** appear above the lock screen. Atoll's own changelog says its window-based volume, brightness and keyboard HUDs sit below the lock screen shield, so it suppresses them while locked. [verified: `CHANGELOG.md` line 107]
- So the only way Atoll shows content over the lock screen is the private delegation. [inferred from the code and changelog together]
- There is no public API to draw in the lock-screen session. [inferred from general Apple platform knowledge; not checked against Apple docs in this pass]

**Permissions.** None for the window itself. Location (weather), Calendars and Reminders (widgets), and Apple Music (animated artwork) have their own prompts. [verified: `pbxproj` usage-description keys list: calendars, reminders, location, Apple Events, Bluetooth, camera, microphone, desktop/documents/downloads folders; `Info.plist` Apple Music key]

**Breakage risk: HIGH.** The private-space delegation and the in-house wrapper depend on undocumented symbols. The package is on a branch, so an upstream change can silently change behaviour. A future macOS may move the lock screen to a different level or session model, which would break the panel's visibility without a crash. The mitigation in the source is limited: the window is kept alive and hidden on unlock.

---

## 10. Full-screen artwork on the lock screen and desktop (wallpaper route)

**What it does.** Shows the current track's artwork, blurred, full-screen on the desktop (and therefore behind the lock screen) and optionally as a looping video (Spotify Canvas). Can switch the desktop wallpaper to the artwork, or to an Apple Aerial video. Restores the previous wallpaper on stop. [verified: `DynamicIsland/managers/FullScreenArtworkWindowManager.swift`, the manager class (259 onward) and the wallpaper functions (1581-1670); `Info.plist` Apple Music usage text, which ties animated artwork to the lock screen wallpaper (paraphrased)]

**How it works (outcome only).** Atoll shows artwork in desktop-level windows, can replace the system wallpaper with the artwork (backing up and later restoring the user's wallpaper settings, which live in an undocumented store), and interferes with the system's wallpaper processes so its artwork stays visible. Rendered artwork is cached as image files. [verified: `FullScreenArtworkWindowManager.swift`]

**Permissions.** No TCC prompt is listed for this path. It writes the user's own wallpaper files and signals processes owned by the same user. [verified: no related entitlement or usage key; [inferred] that no prompt appears]

**Frameworks and APIs.** Public: `NSWindow`, AVFoundation player, `PropertyListSerialization`, `Process`. Undocumented: the wallpaper store and the system wallpaper processes. [verified]

**Risks.**
- Writes to an undocumented private store and changes the user's wallpaper, which is destructive if the backup or restore fails. [verified: restore and backup code exists; [inferred] the failure mode]
- Interferes with system wallpaper processes, which is fragile across macOS releases. [inferred]
- The desktop-level window and the lock screen both depend on the wallpaper store. [inferred]

**Breakage risk: HIGH.** Undocumented file format, undocumented process names, and a user-visible side effect (the wallpaper). The changelog records that the native volume HUD suppression stopped working on macOS 26. [verified: `CHANGELOG.md` line 140]

**Files.** `DynamicIsland/managers/FullScreenArtworkWindowManager.swift` (about 1,700 lines), `DynamicIsland/managers/AnimatedArtworkManager.swift`, `DynamicIsland/components/LockScreen/LockScreenMusicPanel.swift` (uses the artwork-fullscreen setting).

**Relevance to DropNotch.** This is the mechanism behind Atoll's full-screen playback on the lock screen. It does not use the lock-screen window at all; it uses the desktop wallpaper that the lock screen displays. [inferred for the lock-screen-visibility half: Atoll's Info.plist usage text ties Apple Music animated artwork to the lock-screen wallpaper, verified; the macOS behaviour that the lock screen shows the chosen wallpaper is [inferred] from public platform knowledge]

---

## 11. Other lock-screen widgets

### 11a. Weather
- Data: Open-Meteo forecast and air-quality public endpoints, no key. [verified: `DynamicIsland/managers/LockScreenWeatherManager.swift` (lines 706-820, both hosts); ReadMe credits Open-Meteo]
- Location: CoreLocation, when-in-use authorisation, hundred-metre accuracy, requested when the widget needs it. [verified: `LockScreenWeatherManager.swift` lines 1092-1120]
- Also reads the lock flag from the session dictionary in its widget. [verified: `DynamicIsland/components/LockScreen/LockScreenWeatherWidget.swift` around line 128]
- Breakage risk: LOW (public APIs; Open-Meteo is stable and free).

### 11b. Battery (Mac)
- Power sources: public power-source APIs (`IOPSCopyPowerSourcesInfo`, list copy, run-loop notification). [verified: `DynamicIsland/managers/MacBatteryManager.swift` lines 35-36; `DynamicIsland/managers/BatteryActivityManager.swift` lines 92, 239-243, 332-333]
- Breakage risk: LOW.

### 11c. Bluetooth device battery (accessories)
- Uses public Bluetooth device APIs for connection events and a public service-id type, but reads battery levels from **undocumented registry keys** (per-device battery percentages, left/right/case variants) on a device-management HID service. [verified: `DynamicIsland/managers/BluetoothAudioManager.swift` lines 545-547, 1329-1343, 1627-1712]
- Permissions: Bluetooth (always) usage text. [verified: `pbxproj` key]
- Breakage risk: HIGH (undocumented keys; known to differ by device and by macOS version).

### 11d. Timers, reminders, calendar
- Timer widget and reminder widget use the same lock window mechanism (Section 9). [verified: `LockScreenTimerWidgetManager.swift` lines 234-245; `LockScreenReminderWidgetPanelManager.swift` line ~117]
- Reminders and calendars use EventKit with full-access prompts. [verified: `pbxproj` keys for calendars and reminders; the main content view and managers, not traced in detail]
- Breakage risk: the windows as in Section 9 (HIGH); EventKit LOW.

---

## 12. Volume and brightness HUDs (media-adjacent, not media-specific)

- Volume: Core Audio hardware properties (public) with a fallback for devices that report volume through a different channel. [verified: `DynamicIsland/managers/SystemMediaControllers.swift` lines 63-330]
- Brightness: private display-brightness frameworks, loaded at runtime with `dlopen` and `dlsym` (public C runtime calls), with polling fallback. [verified: `DynamicIsland/helpers/CoreBrightnessDisplayClient.swift`, `DisplayServicesDynamic.swift`, `SystemMediaControllers.swift` lines 643-980]
- Native volume HUD suppression: an OS-level process-control mechanism, which the CHANGELOG records as broken on macOS 26. Fragile across releases. [verified: `CHANGELOG.md` line 140; the implementation is in Atoll's on-screen-display manager, not traced here since it is another analyst's lane]
- Breakage risk: brightness HIGH (private); volume LOW-MEDIUM.

---

## 13. Permissions summary (media and lock screen only)

| Permission / entitlement | Who needs it | Evidence |
|---|---|---|
| Accessibility | Media-key tap, TIDAL controls, full-screen detection via the Accessibility full-screen attribute | `MediaKeyInterceptor.swift`, `TidalController.swift`, `FullscreenMediaDetection.swift` |
| Automation (Apple Events) | Music, Spotify AppleScript; Notes (unrelated) | `pbxproj` usage key; entitlements automation key and exception list |
| Audio capture | Waveform, spectrum, per-app volume | `Info.plist` audio capture key; `AudioTap.swift` |
| Screen recording | Declared in `Info.plist` for screen-capture features; not needed by the media paths reviewed here | `Info.plist` screen capture key [inferred that media paths do not use it] |
| Apple Music (MusicKit) | Animated artwork | `Info.plist` Apple Music key; `AnimatedArtworkManager.swift` |
| Location (when in use) | Weather widget | `pbxproj` location keys; `LockScreenWeatherManager.swift` |
| Bluetooth (always) | Accessory battery, connection events | `pbxproj` key; `BluetoothAudioManager.swift` |
| Calendars, reminders | Lock-screen calendar and reminders | `pbxproj` keys |
| Network | Lyrics, artwork, weather, Spotify Web API | multiple |
| Disable library validation | Loading the adapter framework and other bundles | `DynamicIsland.entitlements`; reason [inferred] |
| Not sandboxed | Whole app | no app-sandbox key in `DynamicIsland.entitlements` |

---

## 14. Breakage risk table (macOS updates)

| Dependency | Public / private | Risk | Why |
|---|---|---|---|
| Now Playing private framework via adapter (stream and commands) | private | HIGH | Private symbols; already restricted on 15.4+ |
| Adapter interpreter `/usr/bin/perl` | public binary | MEDIUM | Apple could remove or restrict the interpreter; unlikely soon [inferred] |
| macOS 15.4+ restriction check | private | HIGH | Depends on the private test entry point and an unshipped-source helper binary |
| Music AppleScript | public (scripting) | LOW-MEDIUM | Stable dictionary; undocumented notification name |
| Spotify AppleScript and notification | public / undocumented | MEDIUM | Spotify changes its scripting or notifications |
| Spotify Canvas (web-session cookie, web-player token, internal endpoints) | undocumented, third-party secrets | HIGH | Breaks on any token or endpoint change; terms exposure |
| Spotify Web API (OAuth) | public (third-party service) | LOW | Documented |
| TIDAL Accessibility | public AX API, undocumented UI | HIGH | Depends on the UI tree and menu wording |
| YouTube Music and Cider local APIs | third-party | MEDIUM | Depends on companion app APIs |
| Core Audio process tap | public (14.2+) | MEDIUM | Public API, but aggregate-device and route side effects |
| Media-key event tap | public (Accessibility) | LOW-MEDIUM | System may restrict default taps further |
| Lock distributed notifications and session flag | undocumented | MEDIUM | Widely used; no contract |
| Shielding-window level and collection behaviour | public | LOW-MEDIUM | Public, but visibility over the lock needs the private layer |
| Private-space delegation (SkyLightWindow package on a branch) | private | HIGH | Undocumented symbols; unpinned branch |
| In-house private-space wrapper (window-server symbols) | private | HIGH | Undocumented symbols bound by name |
| Wallpaper store editing and wallpaper-process signalling | undocumented | HIGH | Undocumented file format and processes; user-visible side effects |
| Full-screen detection (AX full-screen attribute) | undocumented attribute | MEDIUM | Comment says stable; undocumented |
| Accessory battery registry keys | undocumented | HIGH | Per-device, per-version keys |
| Mac battery (power-source APIs) | public | LOW | Documented |
| Open-Meteo, LRCLIB | public third-party | LOW | Documented or public; no SLA |
| NetEase lyrics | undocumented third-party | HIGH | Undocumented, regional |
| MusicKit animated artwork (undocumented video URL pattern) | public + undocumented | MEDIUM | Catalogue response shape can change |
| Private display-brightness frameworks | private | HIGH | Not media-specific; listed for completeness |

---

## 15. Licence and attribution notes (for DropNotch's licence check)

- The adapter script carries a BSD-3-Clause header naming its author. [verified: `mediaremote-adapter/mediaremote-adapter.pl`] BSD-3-Clause is compatible with MIT and GPL-3.0 use, but the copyright and licence notice must be kept with the script. [inferred from the licence text, not checked on this pass]
- Atoll's `NOTICE` file does not mention the adapter, the SkyLightWindow package, Open-Meteo or LRCLIB by name. [verified: `NOTICE`; searched for adapter, SkyLightWindow, Open-Meteo and LRCLIB]. [inferred] The adapter's BSD notice may not be carried by Atoll. DropNotch should not copy the adapter binary without its own notice.
- The vendored framework binary has no licence file in the tree. [verified: directory listing] Its licence is therefore [unverified].
- SkyLightWindow is pinned to a branch in Atoll. [verified: `pbxproj`] DropNotch must pin with an exact version (per CLAUDE.md) before any use, and record the licence in `docs/DECISIONS.md` (the package licence was not checked in this pass).
- Third-party data sources (LRCLIB, Open-Meteo, NetEase, the Spotify token endpoints) carry their own terms. None were checked in this pass.

---

## 16. Gaps and what I did not check

- Did not inspect any binary (the adapter framework, the test helper, the SkyLightWindow package). Their behaviour is inferred from the source around them.
- Did not check Apple's documentation for the shielding-window level, `sharingType` and ScreenCaptureKit behaviour, or the lock-screen session model. Those statements are marked [inferred]. The Apple links added in this revision (the shielding-window function, `NSWindow.Level`, `NSWindow.CollectionBehavior`, `NSWindow.sharingType`, the disable-library-validation entitlement) were resolved for existence only; their body text was not read, so they are lookup pointers, not evidence.
- Did not trace the gesture implementation, the on-screen-display manager, the extensions framework, or the full music-manager state machine. Other analysts cover those areas.
- Did not run the test suite or the app.

---

## 17. Summary of what matters for DropNotch

1. **Music controls for the MVP can avoid private APIs for Apple Music and Spotify** (AppleScript plus notifications, both public-ish), and only need the private now-playing framework for generic Now Playing. Atoll itself falls back to Apple Music when that framework is restricted, so DropNotch should put Now Playing behind a protocol with that fallback, as CLAUDE.md requires.
2. **Full-screen now playing on the lock screen is the hardest part and carries the most risk.** Atoll does it two ways, both private or undocumented: a lock-level window handed to a third-party private-space package, or rewriting the wallpaper store and signalling the wallpaper process. Neither has a public equivalent, and the lock-screen window with only public APIs is limited (Atoll itself hides its public-API HUDs while locked). Recommend Shash decides before MVP and that it is excluded from MVP unless Shash accepts the private-API risk.
3. **The waveform and visualiser use the public Core Audio process tap**, and it has a real side effect: it can break AirPods' pause gesture and the Now Playing route on Bluetooth. Atoll gates it. If DropNotch adds it, gate it the same way and test with AirPods.
4. **Lyrics: use LRCLIB only** (public, keyless). Do not use the NetEase endpoints (undocumented, terms exposure). Also gate every lyric request behind the setting, as Atoll learned the hard way.
5. **Energy and licence hygiene.** Atoll polls every 500 ms while locked and runs 30 to 60 fps timers, which conflicts with DropNotch's event-driven rule. The adapter is BSD-3 and the SkyLightWindow package is on an unpinned branch, and Atoll's NOTICE does not name them. DropNotch needs exact pins, its own NOTICE entries, and a DECISIONS.md entry for each dependency before use.

---

## 18. Files written

- `docs/research/atoll-media-lockscreen.md` (this file)
