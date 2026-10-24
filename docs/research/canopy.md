# Canopy: public-page analysis

> Tagging rule: a verified or inferred tag on a heading or a lead-in line applies to every bullet under it, until another tag overrides it. Lines under "Gaps", "Method" or "What I did not check" describe the analysis itself, not the app.

Date fetched: 2026-10-24
Analyst: reference-analyst (clean-room)
Scope: public web pages only. The Canopy binary, DMG and bundled resources were not downloaded or inspected.

## Sources and fetch status

| URL | Fetch | Notes |
|---|---|---|
| https://getcanopy.pro | Worked | Marketing page. |
| https://getcanopy.pro/changelog | Worked | Lists version 1.1 (6 Oct 2026) and 1.09 (August 2026, no day shown). |
| https://getcanopy.pro/privacy | Worked | Says "last updated" only as a relative date ("2 months ago"). |

Caveat: the fetch tool returns a model-generated summary of each page, not the raw HTML. Short quoted phrases are as the summary gave them, so re-check exact wording in a browser before relying on it for product copy. Every claim below is therefore "verified" only to the level of that summary.

Tags used below:
- [verified: home], [verified: changelog], [verified: privacy] mean the page states the claim (via the fetch summary).
- [inferred] means I am deducing it. The reasoning is given.
- [marketing claim] means a performance or quality claim the page makes without evidence. Treat as unverified.

## Feature and behaviour inventory

### Display and layout
- [verified: home] Runs on notched Macs and on "Externals and Macs without a notch". [inferred] So it claims support for every display.
- [verified: home] Describes itself as a "Dynamic Island"-style surface at the top of the screen.
- [verified: changelog 1.09] Non-notch Macs and external monitors are supported.
- [verified: changelog 1.1] Reports a fix for album art being clipped by the notch on one laptop size. [inferred] Notch geometry needs per-model care.
- [verified: changelog 1.1] Reports a fix for an unwanted Dock icon. [inferred] It is meant to run as a background-style app; its exact setup is unknown.
- [verified: changelog 1.1] Reports a fix for lock-screen widgets lingering after unlock. [inferred] The lock-screen UI is a separate surface that must be removed on unlock.

### Now playing and media
- [verified: home] Shows the current track in the island.
- [verified: changelog 1.09] Full controls for Spotify and Apple Music, including album art and scrubbing.
- [verified: changelog 1.09] Now-playing info and controls for Netflix, Twitch and other video platforms.
- [verified: changelog 1.1] Tidal now playing, artwork, live waveform and EQ, alongside Apple Music and Spotify.
- [verified: changelog 1.1] Reports fixes for play/pause with browser players, and for the wrong state after switching from a web video back to a paused app.
- [verified: changelog 1.1] Reports smoother rapid skipping, and a scrubber that grows only while in use.
- [verified: privacy] Spotify and Apple Music controls work locally and send nothing to those services.

### Lock screen, lyrics and widgets
- [verified: home] Shows music and lyrics on the lock screen "before you even sign in".
- [verified: home] Synced (live) lyrics. To fetch them, Canopy sends the track title and artist.
- [verified: privacy] Lyrics are fetched through Canopy's own server, which pulls synced lyrics from LRCLib. The page says the title and artist are not stored or linked to identity.
- [verified: changelog 1.09] Time-synced lock-screen lyrics for the current track.
- [verified: changelog 1.1] Lock-screen widgets for weather, battery, AirPods and Focus, in a row below the clock.
- [verified: changelog 1.1] Reports a fix for repeated lyrics requests to an unavailable provider. [inferred] Some back-off exists in the lyrics path.

### Audio output, EQ and waveform
- [verified: changelog 1.1] Audio output picker redesigned (Liquid Glass styling), replacing the system menu.
- [verified: changelog 1.1] Live waveform and EQ.
- [verified: changelog 1.1] Reports EQ fixes: audio problems on Bluetooth headsets, and the effect persisting after being switched off.
- [verified: changelog 1.1] Reports a fix for a flat waveform when onboarding was skipped. [inferred] The waveform depends on a setup or permission step.
- [verified: changelog 1.1] Says microphone and camera access are no longer requested. [inferred] An earlier version asked for one, probably for audio capture.

### AirPods and Bluetooth
- [verified: home] AirPods Pro and AirPods Max: shows battery and volume "the moment they connect". The page says "every pair" stays visible.
- [verified: changelog 1.09] AirPods overlay with live battery and connection status in the notch.
- [verified: changelog 1.1] AirPods listening mode (Transparency, Noise Cancellation or Adaptive) shown in the notch and on the lock screen, in a system-like icon style.
- Note for DropNotch: use SF Symbols or our own icons; never reuse Canopy's or Control Centre's artwork.

### Charging and power
- [verified: home] A "Charging, at a glance" section. No details given.
- [verified: changelog 1.09] Charging states and low-power alerts with battery animations.
- [verified: privacy] Battery status is read locally and "never leave your device".

### Weather
- [verified: home] Temperature and sky display in the notch.
- [verified: changelog 1.09] Live weather in the notch.
- [verified: privacy] Apple WeatherKit receives the user's approximate location.
- [verified: changelog 1.1] Weather also appears as a lock-screen widget.

### File tray, AirDrop, clipboard, calendar, HUD
- [verified: home] File tray is mentioned in the intro, with no detail.
- [inferred] AirDrop, clipboard history, calendar and HUD replacement are not mentioned on any of the three pages. Do not assume Canopy has them. The homepage notes calendar, AirDrop, clipboard, HUD and customisation are absent from its own copy.

### Diagnostics
- [verified: changelog 1.1] Settings > Diagnostics shows live CPU, memory and audio status, with a copy button for bug reports. The page says "Nothing is sent anywhere."

### Customisation and settings
- [verified: changelog 1.1] Reports fixes to some Settings toggles and visual tweaks to the expanded player.
- [inferred] No customisation feature list is given on the homepage.

### Performance (all marketing claims)
- [marketing claim] Homepage: about 20% CPU while music plays.
- [marketing claim] Homepage: 0 MB memory at idle.
- [marketing claim] Homepage: "Event driven, never polling." It wakes on events, not a timer loop. "When nothing changes, Canopy does nothing."
- [marketing claim] Homepage: says it won't drain the battery.
- [marketing claim] Changelog 1.09: "Lightweight, efficient performance."
- [verified: changelog 1.1] Reports lower memory use from keeping artwork no larger than it is shown. This is a stated change, not a measured figure.

Note: the 20% CPU figure while music plays is high for a notch app. Canopy's own diagnostics panel (1.1) would let a user check this. Use it as a benchmark only after measuring, not as a target.

### Pricing and licensing
- [verified: home] Not a subscription. Sold through getcanopy.pro, with pricing on the download page.
- [verified: home] A Halloween sale lists 15 EUR reduced to 8.99 EUR, ending 31 October. Time-limited; do not treat as a stable price.
- [verified: home] One licence covers two Macs. A bonus device claim gives a third.
- [verified: home] Canopy 1 owners get Canopy 2 included, and must download it again.
- [verified: home] Licence recovery, Refund and Changelog pages exist.
- [verified: changelog 1.09] One licence covers two Macs, or three after claiming a free bonus device, with "verified device management".
- [verified: changelog 1.09] 48-hour free trial with no card required.
- [verified: privacy] Activation codes are checked against Canopy's server and re-checked at every launch. The code and a device identifier are sent. Users can view and remove activated devices.
- [verified: privacy] Payments are handled by Stripe.

### Minimum macOS version
- [inferred] Not stated on any of the three pages. The changelog names "macOS" in 1.09 but gives no version. The Liquid Glass styling in 1.1 suggests a recent macOS release (the Liquid Glass design system is an Apple design language, which I believe arrived with macOS 26). Left unknown, because the three public pages don't state it.

### Privacy and network use
- [verified: privacy] Says no personal data is collected, stored or sent.
- [verified: privacy] No analytics, no tracking, no telemetry. Crash reporting is not mentioned.
- [verified: privacy] No ads, affiliate tracking or embedded third-party services. No data is shared with third parties.
- [verified: privacy] Under normal use the app "does not communicate with any servers". Exceptions:
  - Lyrics (if enabled): title and artist go to Canopy's server, then to LRCLib.
  - Weather: Apple WeatherKit gets approximate location.
  - Update checks: contact Canopy's server; the page says no personal data is included.
  - Licence: activation code and device identifier are sent on activation and at each launch.
  - Payments: Stripe.
- [verified: privacy] No retention periods are given beyond "lyrics requests are not stored".
- [verified: privacy] Clipboard handling, file handling and permissions are not addressed.
- [verified: privacy] Under-13s are not targeted.
- [inferred] Contradiction to note: the homepage says "When nothing changes, Canopy does nothing.", and the privacy page says there are no server calls under normal use. The launch-time licence check is an exception the privacy page admits, so the homepage claim should not be read as "no network". It is a launch-time and event-driven call, not a polling one.

## Changelog timeline

| Version | Date | What it shows |
|---|---|---|
| 1.1 (current) | 6 Oct 2026 | AirPods listening mode, lock-screen widgets, Liquid Glass audio picker, Tidal support, Diagnostics panel, lower memory, mic/camera permission removed, many fixes. |
| 1.09 | August 2026 (no day shown) | Canopy 2 launch: Spotify/Apple Music, video platforms, AirPods overlay, weather, charging states, external displays, licence model, trial. |

Observations:
- [verified: changelog] The version label is "1.09" in one heading and "Canopy 2" in the body. The changelog treats 1.09 as the Canopy 2 launch. Note that version naming on the site is inconsistent; do not rely on it for version comparisons.
- [verified: changelog] There are no entries on macOS version compatibility. Nothing about macOS 15.4 or any MediaRemote change appears on these pages. The brief suggested MediaRemote changes in macOS 15.4+ may be in the changelog; they are not. Treat that as unverified.
- [verified: changelog] The changelog gives no Apple update response (no "fixed in macOS X.Y" entries). Lock-screen and waveform fixes exist, but without a cause.
- [verified: changelog] Removing the microphone/camera request in 1.1 is the only permission change the changelog lists.
- [inferred] Fast cadence: a major launch then a point release within about two months.

## Technique guesses (all inferred)

Canopy is closed-source. None of the following has been verified in code. Each guess is listed with the feature it likely serves and the apparent risk.

1. Now playing for Apple Music and Spotify.
   - Likely: distributed notifications from the players (both post playback-state notifications), plus AppleScript or ScriptingBridge for transport controls. Apple Events needs the Automation (Apple Events) TCC permission per target app.
   - Risk: low for the notifications, medium for Apple Events permissions.

2. Now playing for all other apps (browser video, Netflix, Tidal, Twitch).
   - Likely: the MediaRemote private framework (the system Now Playing service). Browser play/pause fixes in 1.1 point to a generic path, not per-app scripting.
   - Risk: high. MediaRemote is private. Apple has restricted it on newer macOS releases for non-entitled apps. Expect it to break on a macOS update. The brief's claim of a macOS 15.4 change is not on these pages, so I cannot confirm it.
   - DropNotch should put this behind a protocol with a fallback (per CLAUDE.md).

3. Lock-screen display ("before you even sign in").
   - Likely: a private window-server mechanism to show a window over the login window, or a helper running in the login session.
   - Public alternative: none that reliably shows UI over the login window.
   - Risk: very high. This is the most fragile feature. It probably relies on private APIs [inferred; not checkable from the public pages], and the 1.1 fix for lingering widgets suggests it is hard to get right.

4. Notch geometry and placement.
   - Likely: the public screen safe-area APIs (macOS 12+) to find the notch. Non-notch placement uses a computed top-centre region.
   - Risk: low.

5. Dock hiding and background behaviour.
   - Likely: set up as a background (accessory) app, which macOS supports publicly. Canopy's exact setup is not known.
   - Risk: none.

6. Live lyrics.
   - Likely: time-synced lyrics via a server proxy calling LRCLib. The proxy design is what the privacy page describes.
   - Risk: depends on LRCLib availability and terms. Not an Apple API risk.

7. Weather.
   - Likely: WeatherKit (public Apple service, needs a developer key and entitlement on the app's side) plus CoreLocation approximate-location permission.
   - Risk: low. Requires an Apple Developer account and WeatherKit quota.

8. AirPods battery, connection and listening mode.
   - Likely: Bluetooth battery data via private or undocumented keys (the same family as IOBluetooth battery keys). Listening mode and volume likely need private Bluetooth/AirPods APIs or the Control Centre icon set (not a public API).
   - Risk: high. Undocumented keys change between macOS and AirPods firmware versions.

9. Charging indicator and low-power alerts.
   - Likely: the public IOKit power-source APIs with change notifications.
   - Risk: low.

10. Waveform and EQ.
   - Likely: audio capture of the playing app's output, either a Core Audio process tap (public API on macOS 14.2+) or a virtual device. The removal of mic/camera permission in 1.1 suggests the earlier design captured audio through a mic-style permission path. The current design may use the system audio-capture permission instead.
   - EQ: likely an AVAudioEngine or Audio Unit graph routing the tapped output.
   - Risk: medium. Process taps are public but need the audio-capture permission. EQ problems on Bluetooth headsets in 1.1 suggests a sample-rate or buffer issue.

11. Diagnostics panel (CPU, memory, audio status).
   - Likely: host and task statistics (public Mach calls) plus audio state. "Nothing is sent anywhere" is consistent with local-only.
   - Risk: low.

12. Licence and device management.
   - Likely: server activation with a device identifier, re-checked on launch; Stripe for payments. Canopy's server holds the activation list.
   - Risk: none from macOS updates; a server dependency.

13. Update checks.
   - Likely: a request to Canopy's server. The page does not name an update framework.
   - Risk: none from macOS updates.

14. Liquid Glass audio picker and the Control Centre icons.
   - Likely: newer SwiftUI or AppKit glass materials on a recent macOS. DropNotch should use SF Symbols or its own icons, and must not reuse Canopy's icons.
   - Risk: low, but tied to a newer minimum macOS.

## Five-line summary for DropNotch

1. Canopy's public claims map closely onto DropNotch's MVP surfaces (now-playing, lock-screen media, AirPods/charging, file tray), but the public pages say nothing about AirDrop, clipboard history, calendar or customisation depth, so DropNotch cannot rely on Canopy for those.
2. The hardest pieces are the ones Canopy probably does with private APIs [inferred]: now-playing for non-Apple apps (MediaRemote-style), the lock-screen surface, and AirPods battery/listening mode. Each needs a protocol with a fallback, as CLAUDE.md requires, and a note in docs/RISKS.md.
3. Canopy's privacy stance is a useful bar: no analytics or telemetry, local processing, and only lyrics, weather, update checks and licence checks go to the network. DropNotch's MVP can meet that with no server if it drops lyrics and licensing.
4. Event-driven design ("When nothing changes, Canopy does nothing.") and a diagnostics panel with live CPU and memory are worth copying as principles. The performance numbers (20% CPU while playing, 0 MB idle) are unverified marketing claims, so DropNotch should measure its own budget rather than match them.
5. Canopy's changelog shows the real maintenance cost: fixes for browser and web-video play/pause, Bluetooth audio, and lock-screen leftovers. Plan for media-control breakage on each macOS release and keep a test matrix for browser players and Bluetooth headsets.
