# Feature matrix

Status: Phase 1, 2026-10-24. Priorities approved by Shash; decisions are recorded in [DECISIONS.md](DECISIONS.md) as D1–D10.

Sources. Each tag points to a clean-room note, and every note cites its own page or source path:
- Canopy: [research/canopy.md](research/canopy.md) (the three public pages only, fetched 2026-10-24)
- Atoll v2.3.3-alpha.4 (commit 2e15e5f): [research/atoll-media-lockscreen.md](research/atoll-media-lockscreen.md), [research/atoll-tray-clipboard-utilities.md](research/atoll-tray-clipboard-utilities.md), [research/atoll-system-shell.md](research/atoll-system-shell.md)

Tags:
- **[V]** verified: stated on a Canopy page, or seen in Atoll's source or README, per the research note.
- **[I]** inferred: reasoning or general platform knowledge, not confirmed on a page, in source or in Apple documentation during Phase 1.
- Columns without a tag: "DropNotch approach" and "Priority" are proposals, not claims. "Breakage risk" is a judgement and is **[I]** unless tagged.

Priority rule: a feature earns MVP by making a frequent action faster. MVP = music controls, file tray + AirDrop, clipboard history, quick notes and a customisable notch layout, plus the shell they need.

## What v0.1.0 ships

The "DropNotch priority" column below is the Phase 1 plan. As of release/v0.1.0 (2026-11-01):

- **Ships in v0.1.0:** notch panel, geometry and hover; the pill on screens without a notch; the ⌃⌥N hotkey with keyboard focus (D30, D40); menu-bar item; launch at login; Settings with module order and compact-slot choice (D34); Now Playing for Music and Spotify with artwork, progress bar and seek (D22–D26); the decorative compact waveform (D28); notes (D31); file tray with drag in and out, AirDrop and Share (D32, D40); clipboard history (D33); no analytics or telemetry. Distributed as an ad-hoc-signed DMG (D41).
- **Not in v0.1.0, planned for v0.2:** several displays at once, hiding from screen capture, the diagnostics panel, Now Playing for any app (MediaRemote), the real waveform, shuffle and repeat, calendar, timer, battery and Bluetooth, Sparkle updates, Developer ID signing and notarisation.
- **Home dashboard (Shash, 2026-11-01):** the README roadmap names a v0.2 Home dashboard with a music card, calendar, battery and terminal. Calendar and battery are v0.2 rows below; the terminal row still says Later (it needs a dependency and a security review for subprocesses), so its date isn't settled. **Update (v0.2.0, 2026-11-10):** the terminal shipped in v0.2 as its own tab (D48), not a Home card.
- **Not in v0.1.0, from MVP rows:** Quick Look, thumbnails and open/reveal in the tray (D32); favourite in Now Playing (D26); click-to-open and a VoiceOver element for the closed notch.
- Device checks still open for the release are listed in TASK.md, "Release checklist".

## Shell and layout

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| Notch panel above the menu bar, all Spaces, over full-screen apps | Yes [V]; reports a fix for an unwanted Dock icon [V]; background-app setup [I] | Yes: borderless non-activating NSPanel, level above the menu bar, all-Spaces + full-screen-auxiliary [V] | Same public NSPanel configuration. Skip Atoll's private Spaces wrapper. | Public [V] | None [V] | Low | MVP | Atoll also pins to a private window-server Space [V]. We test on device whether the public flags are enough before considering it. |
| Notch geometry | Per-model fixes (15" Air art clipping) [V] | `safeAreaInsets` + auxiliary top areas [V]; empirical 4 pt bleed, 32 pt fallback height [V]; fractional top inset on some hardware [V] | Same public APIs, frames rounded to pixels | Public [V] | None | Low | MVP | Constants need tuning on a real notched Mac. |
| Hover to expand (closed → peek → open) | Not described [I] | SwiftUI hover plus a 1 Hz polling fallback for life of the view; 0.3 s open delay, 100 ms exit debounce [V] | AppKit tracking area on the notch-sized panel; one-shot open-delay and exit-debounce timers only | Public | None [I] | Low to medium (top-edge hover reliability) [V: Atoll's comment] | MVP | No idle loop. Atoll notes SwiftUI hover is unreliable at the top pixel row [V]. Check this on device. |
| Hotkey to open | Not mentioned [I] | Yes, via KeyboardShortcuts package [V] | Global hot key (Carbon hot-key API, directly or via KeyboardShortcuts) [I] | Public (legacy Carbon) [I] | None for hot keys [I] | Low | MVP | Dependency choice is D10. |
| Non-notch / external display fallback | Yes [V] | Notch or pill style; optional hide-until-hover driven by a 50 ms poll [V] | Pill when `safeAreaInsets.top == 0`; no hide-until-hover poll | Public [V] | None | Low | MVP | |
| Notch on several displays at once | Not stated | Yes: one window per display; displays identified by localised name in many places [V] | One panel per display keyed by display ID | Public | None | Medium | v0.2 | MVP shows one display (D9). |
| Customisable notch layout | Settings toggles only, no layout claims [V] | Many style options; no free-form layout seen [I] | Fixed slots (compact left, compact right, ordered expanded tabs) chosen in Settings | Public | None | Low | MVP | Scope is D8. |
| Menu-bar item with Settings and Quit; agent app (no Dock icon) | Not stated; likely a background app [I] | MenuBarExtra + LSUIElement; switches to regular policy while Settings is open [V] | Same, set through project.yml | Public [V] | None | Low | MVP (Phase 2 task) | |
| Launch at login | Not stated | Yes, via a package on a branch pin [V] | `SMAppService.mainApp` (macOS 13+) [V: https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp] | Public [V: same] | None (user can disable in System Settings) [I] | Low | MVP | No dependency needed [I]. |
| Hide from screen capture | Not stated | Sets window `sharingType` [V] | Don't rely on `sharingType`: Apple says not to use it to hide content [V: https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none]; exclude own windows via ScreenCaptureKit filters instead [I] | Public [V] | None | Medium: needs an on-device check [I] | v0.2 | Useful when clipboard history is visible during screen sharing. |
| Diagnostics panel (own CPU, memory) | Yes, local only [V] | Memory watchdog every 8 s from launch [V] | On-demand read of own memory footprint while the panel is open | Public Mach API; no current Apple reference page found [I] | None | Low | v0.2 | Lets users check our energy claims instead of trusting marketing. |

## Media

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| Now playing + controls: Apple Music, Spotify | Yes, incl. art and scrubbing; processed locally [V] | Distributed notification + AppleScript per app [V] | Same technique, behind a `NowPlayingSource` protocol | Public scripting; notification names undocumented [V] | Automation (Apple Events) per target app [I] | Low to medium [V: Atoll risk table] | MVP | Event-driven: the player posts a notification on change [V]. **Built** (`feat/now-playing-scripting`, 2026-10-25; D22–D24): title, artist, play/pause, next and previous for Music and Spotify, in the open notch. Commands are raw Apple Events to the player's pid (D22). Artwork, the progress bar and seek are built on `feat/now-playing-media` (D25, D26; device checks open). Favourite is not built (D26). |
| Now playing: any app (browsers, Netflix, Twitch, YouTube) | Yes [V] | MediaRemote stream via an Apple-signed interpreter + bundled adapter framework; in-process MediaRemote commands; launch-time availability check [V] | Optional provider behind the same protocol, with fallback to Music/Spotify | **Private** [V] | None for DropNotch: the framework loads into `/usr/bin/perl`, not our process, so no hardened-runtime exception is needed [V: RISKS.md §1.1]. Atoll sets one anyway [V]. | **High**: restricted since macOS 15.4 [I: community knowledge; Atoll's workaround and check are V] | v0.2 | D2. ungive/mediaremote-adapter is BSD-3-Clause [V: upstream LICENSE]; build it from source, never copy Atoll's binary. |
| Compact view: artwork left, waveform right | Track in island, live waveform [V] | Real waveform from a Core Audio process tap (macOS 14.2+) at 30–60 fps timers [V] | MVP: decorative waveform animating only while playing and visible. Real tap later. | Public (tap is 14.2+) [V] | Audio capture, tap only [V] | Medium for the tap: tapping Spotify broke the AirPods pause gesture on Bluetooth [V] | MVP (decorative) / v0.2 (real) | D2. Deployment target 14.0 is below the tap's 14.2 [V]. Artwork built on `feat/now-playing-media` (D25, D26); the compact view and waveform are built on `feat/compact-slot` (D28). |
| Seek / scrubber, shuffle, repeat | Scrubbing [V] | Mixed: MediaRemote, AppleScript, Accessibility, Web API [V] | AppleScript player position for Music/Spotify | Public scripting | Automation | Low to medium | MVP (seek), v0.2 (shuffle/repeat) | Progress bar and seek built on `feat/now-playing-media` (D26; device checks open). Shuffle and repeat not built. |
| Other sources (TIDAL, YouTube Music, Cider, Amazon) | TIDAL [V] | Companion APIs, Accessibility scraping (TIDAL), filtered Now Playing [V] | Only via the generic provider | Mixed | Accessibility for TIDAL scraping [V] | High (UI scraping) [V] | Later | |
| Synced lyrics | Yes, via Canopy's server to LRCLib [V] | LRCLIB, NetEase fallback (undocumented) [V] | LRCLIB only, request only when the setting is on | Public third-party [V] | Network | Low (no SLA) [V] | Later | Sends title and artist off the Mac; needs privacy copy. |
| Audio output picker | Yes [V] | Not analysed | CoreAudio device list | Public [I] | None [I] | Low | Later | |
| EQ | Yes; reports EQ fixes for audio problems on Bluetooth headsets [V] | Not found | — | — | — | — | Skip | Not a frequent action. |
| Per-app volume | Not stated | CoreAudio process taps, 1.5 s/5 s polls while visible [V] | — | Public (14.2+) [V] | Audio capture [V] | Medium [V] | Skip | |
| Media keys | Not stated | Session event tap [V] | — | Public [V] | Accessibility [V] | Low to medium | Skip | Not needed for the MVP: Apple docs don't describe media-key routing to third-party apps [I]. |
| Animals when nothing is playing (DropNotch's own idea) | Not mentioned | Not confirmed [I] | SwiftUI sprite animation, paused when not visible or in Low Power Mode | Public | None | Low | Later | Visual, not productivity. Animation energy needs a budget (ARCHITECTURE.md). |

## Productivity

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| File tray: drop in, drag out, Quick Look, open/reveal | Named on the homepage, no detail [V] | AppKit drag and drop, bookmarks, temp copies, JSON persistence, QuickLook thumbnails [V]; unsandboxed, plain bookmarks [V] | Same public APIs; storage model per D6 | Public [V] | Desktop, Documents and Downloads prompt on first access [V: https://developer.apple.com/documentation/bundleresources/information-property-list/nsdesktopfolderusagedescription] | Medium: Atoll records a bookmark-option regression [V] | MVP | Atoll has no tray tests [V]. We need them. v0.1.0 ships drop in and drag out with tests (D32); Quick Look and open/reveal are not built. |
| AirDrop from tray | Not mentioned [I] | `NSSharingService(named: .sendViaAirDrop)` [V]; also a picker-harvesting trick [V] | `.sendViaAirDrop` directly; no picker trick | Public [V] | None beyond user action [I] | Low [V] | MVP | |
| Share to other services | Not mentioned | Sharing-service enumeration + picker [V] | `NSSharingServicePicker` | Public [V] | None | Low | v0.2 (planned); shipped in v0.1.0 | Built with the tray (D32), then moved from `ShareLink` to the picker for keyboard access (D40). |
| Clipboard history | Not mentioned [I] | Polls `changeCount` every 0.5 s [V]; no concealed/transient skipping [V]; persistence on by default, text in UserDefaults [V] | Poll `changeCount` (no public change notification exists [I]); skip concealed/transient types; local only; never logged | Public [V] | Paste-access prompt on programmatic reads from macOS 15.4 [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum/ask] | Low (polling); medium (read prompts) [V/I] | MVP | The only always-on poll in the MVP. Defaults are D7. |
| Quick notes | Not mentioned | Defaults-backed list, 1.5 s autosave debounce [V] | Plain files in Application Support, debounced save | Public | None | Low | MVP | |
| Apple Notes sync | Not mentioned | AppleScript, opt-in [V] | — | Public scripting [V] | Automation [V] | Medium [V] | Skip | |
| User-chosen calendar or notes panel | Calendar not mentioned [I] | EventKit with change notifications; a 60 s loop on the lock screen [V] | EventKit + store-changed notification; no loop | Public [V] | Calendars (full access) [V] | Low [V] | Notes panel MVP; calendar v0.2 | Ask for Calendars only when the calendar panel is first chosen. |
| Reminders | Not mentioned | EventKit [V] | EventKit | Public [V] | Reminders [V] | Low | Later | |
| Timer | Not mentioned | Own 1 s countdown [V]; also mirrors the Clock app via Accessibility scraping and log stream [V] | Own timer: one timer aligned to the end time, 1 Hz UI tick only while visible | Public | None | Low (own); High (Clock mirror) [V] | v0.2 | Never scrape the Clock app. |
| Terminal | Not mentioned | SwiftTerm, login shell [V] | Third-party terminal view | Public, third-party [V] | None [I] | Low [V] | v0.2 (shipped, D48) | SwiftTerm 1.99.3, pinned by commit; security-auditor design and code reviews; commands use DropNotch's permissions, disclosed. |
| Keep awake | Not mentioned | IOPMAssertion, 1 s ticker while active [V] | IOPMAssertion, no ticker | Public [V] | None | Low [V] | Later | Not in DropNotch's list. |

## System status

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| Mac battery + charging indicator | Yes, read locally [V] | IOKit power sources + run-loop change source; one event per changed property [V] | Same | Public [V] | None [V] | Low [V] | v0.2 | Fully event-driven [V]. |
| Bluetooth/AirPods connect animation | AirPods overlay on connect [V] | Undocumented distributed notifications plus a 3 s unconditional poll [V] | IOBluetooth's documented connect/disconnect registration (Atoll doesn't use it) [V] | Public [V] | Bluetooth [V] | Medium | v0.2 | No poll. |
| AirPods battery (device, per bud, case) | Yes [V] | IOBluetooth, IORegistry keys, `pmset` and `system_profiler` parsing, CoreBluetooth Battery Service [V] | Behind a `BluetoothBatteryProvider` protocol; hide the figure when no source works | **Private/undocumented** for AirPods [V] | Bluetooth [V] | **High** [V] | Later | No subprocess parsing in the app. |
| AirPods listening mode | Yes [V] | Undocumented notifications + long-lived `log stream` child [V] | — | Private [V] | None declared [V] | High [V] | Skip | Reads other daemons' logs: privacy concern. |
| AirPods volume | Yes [V] | Not analysed | System output volume via CoreAudio [I] | Public [I] | None [I] | Low | Later | |
| Weather (temperature) | Yes, WeatherKit with approximate location [V] | Open-Meteo or wttr.in + CoreLocation; Location requested at launch by default [V] | WeatherKit or Open-Meteo (pick at v0.2); ask Location on first enable | Public [V] | Location [V] | Low (Open-Meteo) [V] | Later | WeatherKit needs a paid Apple Developer Program membership and an App ID capability [V: https://developer.apple.com/help/account/services/weatherkit/]. |
| Air quality (AQI) | Not stated | Open-Meteo air-quality endpoint [V] | Same provider as weather | Public third-party [V] | Location | Low | Later | |
| Focus indicator | Lock-screen widget [V] | Undocumented files, 2 s poll, Full Disk Access prompt [V] | — | Private [V] | Full Disk Access [V] | High [V] | Skip | |
| Volume / brightness / backlight HUD replacement | Not stated | Stops the system OSD helper; private CoreBrightness; IORegistry [V] | — | Private [V] | Accessibility [V] | High [V] | Skip | |
| CPU/GPU/memory/network/temperature stats | Not stated | Mach/sysctl (public), private CPU and temperature interfaces [V] | — | Mixed [V] | None | High (temperature) [V] | Skip | |
| Camera/mic, screen recording, Caps Lock indicators | Not stated | CoreMediaIO/CoreAudio listeners, process list, NSEvent [V] | — | Mixed [V] | — | Low to medium [V] | Skip | macOS shows camera (green), microphone (orange) and system-audio recording (purple) indicators [V: https://support.apple.com/en-gb/guide/mac-help/mchlp1446/mac]. |

## Lock screen

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| Full-screen now playing on the lock screen | Music and lyrics on the lock screen before sign-in [V] | Shielding-level window delegated to a private Space via the SkyLightWindow package (branch pin) [V]; or rewrites the wallpaper store and stops wallpaper processes [V] | None public. If ever built: SkyLight route behind a protocol, opt-in. Never the wallpaper route. | **Private** [V] | None [V] | **High** [V] | Later (D3) | Atoll's changelog says public-API windows sit below the lock shield [V]. |
| Lock screen: Mac battery, audio-device battery, AQI, temperature | Weather, battery, AirPods, Focus widgets [V] | Same private window route; 500 ms lock-state poll [V] | As above | **Private** [V] | As per data source | **High** [V] | Later (D3) | "Temperature" read as outdoor temperature, like Canopy's widget [I]. Please confirm. |

## Distribution, privacy and things not to build

| Feature | Canopy | Atoll | macOS API / approach for DropNotch | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority | Notes |
|---|---|---|---|---|---|---|---|---|
| No analytics or telemetry | Stated [V] | Not checked | Policy (CLAUDE.md) | — | — | — | MVP | |
| Updates | Update checks contact Canopy's server [V]; mechanism not stated [I] | Sparkle 2.7.0, four channels, EdDSA-signed appcasts served from the repo's raw host [V] | Sparkle, exact pin, appcast on GitHub Releases | Public third-party [V] | Network | Low [V] | Later | D10; needs Developer ID first. |
| Licence checks, trial | Yes, checked at every launch [V] | — | — | — | — | — | Skip | Open source. |
| Extension RPC server | — | Loopback WebSocket that trusts a client's self-declared bundle ID [V] | — | — | — | Security: high [V] | Skip | |
| LocalSend transfer | — | TLS delegate accepts any server certificate [V] | — | — | Local network [I] | Security: high [V] | Skip | |
| Other Atoll extras (camera, AI and usage-tracking features, downloads, colour picker) | Not stated | Listed in the README [V]; not analysed | — | — | Camera, Screen Recording for some [V] | — | Skip | Outside DropNotch's productivity scope. |
