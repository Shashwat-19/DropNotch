# Atoll: system status, app shell and project-wide analysis

> Tagging rule: a verified or inferred tag on a heading or a lead-in line applies to every bullet under it, until another tag overrides it. Lines under "Gaps", "Method" or "What I did not check" describe the analysis itself, not the app.

Date: 2026-10-24
Analyst: reference-analyst (clean-room)
Source: `reference/atoll/` checked out at tag v2.3.3-alpha.4, commit 2e15e5f (GPL-3.0). Paths below are relative to the repository root, so `reference/atoll/DynamicIsland/...` is the file.
Scope: A (system info and status features), B (app shell), C (project-wide), D (feature index). Media, lock-screen rendering, tray, clipboard and utilities are covered by `docs/research/atoll-media-lockscreen.md` and `docs/research/atoll-tray-clipboard-utilities.md`.

## Method and limits

- Read source text only. Nothing was built, run, or inspected as a binary.
- Swift package sources are not in the checkout. Anything about what a package does internally is [inferred] from its name and how Atoll calls it. Package licences are [inferred] from upstream knowledge and must be confirmed by `dependency-manager`.
- Atoll's README makes feature claims. Those are recorded as claims, not as runtime-tested behaviour.
- Atoll's shell files state they derive from boring.notch (GPL-3.0). Only techniques and the public/private API mix are recorded here. No code, identifiers, UI strings or assets are reproduced.
- Tags: [verified](path) means the source at that path shows it. [inferred] means a deduction; the reasoning is given.
- Breakage risk is rated low / medium / high for a future macOS update, with the reason.

## Key findings for DropNotch

1. The notch window is a borderless, non-activating `NSPanel` with a high window level, full-screen-auxiliary and all-Spaces collection behaviour, and no click-through flag. Its frame is resized to the current content, so a closed notch covers only a notch-sized area (see B1). [verified](reference/atoll/DynamicIsland/components/Notch/DynamicIslandWindow.swift)
2. Atoll pins its notch to every Space through a private window-server "Spaces" wrapper at maximum level. This is the single most fragile shell dependency and is not needed for an MVP that uses public collection behaviour. [verified](reference/atoll/DynamicIsland/private/CGSSpace.swift)
3. Notch geometry is public: `safeAreaInsets` plus the two auxiliary top areas. Non-notch and external displays use a user-selectable pill style, with a fixed fallback height. [verified](reference/atoll/DynamicIsland/sizing/matters.swift)
4. Energy: several always-on loops exist. The hover loop wakes at 1 Hz for the life of the view, an 8-second memory watchdog runs from launch, and a 3-second Bluetooth poll is unconditional. Atoll does not follow an event-driven default; DropNotch should not copy these. [verified](reference/atoll/DynamicIsland/ContentView.swift), [verified](reference/atoll/DynamicIsland/managers/MemoryUsageMonitor.swift), [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)
5. The most fragile features are the ones built on private or undocumented data: AirPods listening mode, Bluetooth per-bud battery (several undocumented sources), Focus-state reading, CPU frequency and temperature (private IOReport and SMC), and native HUD suppression (freezing the system OSD helper process). None should be in the MVP. Battery, charging, calendar, weather and the connect HUD can be done on public APIs.

---

## 0. Feature summary for this file

| # | Feature | Area | Public or private core | Breakage risk | Always-on cost |
|---|---|---|---|---|---|
| A1 | Mac battery and charging state | System | Public (IOKit power sources) | Low | None (event-driven) |
| A2 | Battery HUD (charging, low, full) | System | Public | Low | None |
| A3 | AirPods and Bluetooth battery | System | Mixed; several undocumented sources | High | 3 s poll plus cached subprocesses |
| A4 | Bluetooth connect HUD | System | Mixed (named distributed notifications) | Medium | Shares A3 poll |
| A5 | AirPods listening mode | System | Private notifications and log stream | High | Long-running child process |
| A6 | Weather and air quality | System | Third-party HTTP APIs, public CoreLocation | Low (Open-Meteo) to medium (wttr.in) | 30 min refresh, on demand |
| A7 | Calendar and reminders | System | Public (EventKit) | Low | 60 s lock-screen loop, 15 s reload, 1 s reminder ticker |
| A8 | CPU, GPU, memory, network, disk, temperature | System | Public (Mach, sysctl); private (IOReport, SMC) | High for temperature/frequency | 1 to 60 s, only while visible |
| A9 | Focus / Do Not Disturb state | System | Undocumented files and logs | High | 2 s file-date poll (default on) |
| A10 | Camera and microphone in-use indicator | System | Public-ish (CoreMediaIO, CoreAudio listeners) | Low to medium | None (listeners) |
| A11 | Screen recording indicator | System | Process-list check | Medium | Spawn per app activation |
| A12 | Caps Lock indicator | System | Public (NSEvent monitors) | Low | None |
| A13 | Keep-awake (caffeinate) | System | Public (IOKit power assertions) | Low | 1 s ticker while active |
| A14 | Siri visibility (hide overlays) | System | Public (CGWindowList) | Medium | Up to ~33 Hz while locked |
| A15 | Volume, brightness, keyboard-backlight HUD replacement | System | Mixed; private frameworks and process freezing | High | Event tap; watcher loop |
| A16 | Menu-bar clearance | Shell | Public (Accessibility) | Medium | 3 s poll while tracking |
| A17 | Full-screen detection | Shell | Third-party package plus undocumented attribute | Medium | Event-driven, 500 ms debounce |
| A18 | Memory watchdog and self-relaunch | System | Public (Mach task info, NSWorkspace) | Low (API), poor fit for energy | 8 s poll from launch |
| B1 | Notch panel window | Shell | Public (AppKit) | Low | None |
| B2 | Pinning to all Spaces | Shell | Private (window-server Spaces) | High | None |
| B3 | Notch geometry | Shell | Public (NSScreen) | Low | None |
| B4 | Non-notch and external display style | Shell | Public | Low to medium | Hover poll in hidden mode |
| B5 | Multi-display | Shell | Public | Medium | None |
| B6 | Screen and Space change handling | Shell | Public notifications; undocumented lock notifications | Low to medium | None |
| B7 | Hover, click, expand and collapse | Shell | Public (SwiftUI, NSEvent monitors) | Medium (behaviour) | 1 Hz minimum loop |
| B8 | Settings window | Shell | Public | Low | None |
| B9 | Menu bar item | Shell | Public (SwiftUI MenuBarExtra) | Low | None |
| B10 | Agent app (no Dock icon) | Project | Public (Info.plist key) | Low | None |
| B11 | Launch at login | Shell | Public via package [inferred] | Low | None |
| B12 | Timers and polling in the shell | Shell | Mixed | See section 3 | See section 3 |
| C1 | Entitlements | Project | n/a | Medium (weakening) | n/a |
| C2 | Usage-description keys | Project | n/a | n/a | n/a |
| C3 | Deployment target | Project | n/a | n/a | n/a |
| C4 | Third-party packages | Project | n/a | See table | n/a |
| C5 | Update mechanism (Sparkle, appcasts) | Project | Public (Sparkle) | Low | Sparkle schedule |
| C6 | NOTICE and lineage | Project | n/a | n/a | n/a |

---

## Part A: System information and status

### A1. Mac battery and charging state

What it does: reads the internal battery's percentage, charging flag, time-to-full and low-power mode, and shows them in the closed notch and lock screen.

Frameworks and APIs:
- IOKit power sources (`IOPSCopyPowerSourcesInfo` family, `IOKit.ps`): public. [verified](reference/atoll/DynamicIsland/managers/MacBatteryManager.swift)
- Run-loop notification for power-source changes (`IOPSNotificationCreateRunLoopSource`): public. [verified](reference/atoll/DynamicIsland/managers/BatteryActivityManager.swift)
- Low-power-mode change notification on the process-info state: public. [verified](reference/atoll/DynamicIsland/managers/BatteryActivityManager.swift)

Permissions: none. There is no usage-description key for power data. [verified](reference/atoll/DynamicIsland/Info.plist)

Files: `managers/MacBatteryManager.swift`, `managers/BatteryActivityManager.swift`, `models/BatteryStatusViewModel.swift`, `components/Live activities/DynamicIslandBattery.swift`. All under `reference/atoll/DynamicIsland/`.

Timers and polling: none for the reading itself. Change events are delivered by the run-loop source. A one-second delay queues change events for display. [verified](reference/atoll/DynamicIsland/managers/BatteryActivityManager.swift)

Design note: the manager diffs successive snapshots and emits one event per changed property, so the HUD only fires on real changes. [verified](reference/atoll/DynamicIsland/managers/BatteryActivityManager.swift)

Breakage risk: low. Public API. The time-to-full value can be missing or zero; the code handles nil. [verified](reference/atoll/DynamicIsland/managers/MacBatteryManager.swift)

DropNotch takeaway: build this on public IOKit power sources with the run-loop notification. No poll is needed.

### A2. Battery HUD (charging, low battery, full)

What it does: on a power-state change, expands the closed notch briefly with a battery-specific layout, and plays a sound for low battery. Three HUD kinds are individually toggled in settings. Width depends on the chosen style.

Frameworks and APIs: same as A1, plus the notch sizing path. Public.

Permissions: none.

Files: `models/BatteryStatusViewModel.swift` (event handling around lines 73-210 and low/full alerts 267-290), `DynamicIslandApp.swift` (the notch sizing routine, which sizes the window for the battery HUD). [verified](reference/atoll/DynamicIsland/models/BatteryStatusViewModel.swift), [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift)

Timers: a temporary HUD is shown and hidden by a timed overlay mechanism in the view coordinator. [verified](reference/atoll/DynamicIsland/DynamicIslandViewCoordinator.swift)

Breakage risk: low.

DropNotch takeaway: a timed transient overlay state is a clean pattern for every HUD (battery, Bluetooth connect, listening mode). Keep it in the module protocol.

### A3. AirPods and Bluetooth device battery

What it does: lists connected Bluetooth audio devices and shows the battery of the device, and for AirPods the left bud, right bud and case where available. It shows a percentage in the connect HUD and in the lock-screen Bluetooth widget.

Frameworks and APIs, each labelled:
- IOBluetooth: paired-device list, connection state and the Bluetooth controller's power state. Public framework. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)
- CoreBluetooth: a central manager that connects to nearby peripherals and reads the standard Battery Service. The service is a public Bluetooth standard, but [inferred] AirPods do not usually expose it to third-party centrals, so this path is unlikely to cover AirPods. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift) (a private reader class near the end of the file)
- IORegistry matching on a Bluetooth HID event service, reading per-device battery properties. Undocumented property shape; private in effect. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)
- The power-management command-line tool, run as a child process and parsed for accessory battery entries. Public tool; output format undocumented. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)
- The system profiler tool, run as a child process for its Bluetooth data type and parsed as JSON for vendor and product IDs and fallback battery. Public tool; field names undocumented. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)
- The IORegistry dump tool, run as a child process for listening-mode state (see A5). Public tool; keys undocumented. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)

Permissions: Bluetooth (the always-usage key is present, with a usage string). [verified](reference/atoll/DynamicIsland/Info.plist) (see C2 for the build-setting source of the key.)

Files: `managers/BluetoothAudioManager.swift` (2,949 lines). Key regions: init and observers (around 129-190), 3-second poll (253-260), per-device battery (569-612), pmset fallback (873-940), subprocess batch (1228-1310), registry read (1329-1340), pmset and system_profiler calls (1460, 1583), CoreBluetooth reader (2274 onwards).

Timers and caching [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift):
- Device poll every 3 s, started unconditionally at init.
- Battery refresh cache: 20 s.
- pmset refresh cooldown: 5 s.
- system_profiler reading cache: 30 s time-to-live.
- Subprocess calls run on a utility queue, so they do not block the main thread.

Breakage risk: high. At least four undocumented data sources, parsed by hand. Subprocess calls on the main thread are a crash risk, so keep them off it [inferred]. Per-bud battery depends on the device generation.

DropNotch takeaway: ship only the public subset. Use IOBluetooth paired devices and connection state, and show the device-level battery only if the device reports it through a public path. Keep any undocumented source behind the protocol with a fallback, as CLAUDE.md requires, and do not put subprocess parsing on the MVP path.

### A4. Bluetooth connect HUD

What it does: when a paired audio device connects, shows a timed HUD in the notch with an icon for the device type and the battery value as a bar. It waits briefly for the battery value before showing, and briefly suppresses the volume HUD to avoid two indicators.

Frameworks: IOBluetooth for connection state, DistributedNotificationCenter for named notifications from the Bluetooth stack (names are undocumented, so this part is private in effect), and the view coordinator for the timed HUD. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift)

Animation: no Lottie file is used. The HUD uses an SF Symbol icon and a progress value. [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift) (lines around 1940-1960)

Public alternative: IOBluetooth provides a documented way to register for device connect and disconnect notifications. Atoll does not call it [verified by absence: no registration call appears in the file]. DropNotch should use the documented registration and keep the 3-second poll out of the design.

Permissions: Bluetooth.

Breakage risk: medium. The named-notification path can silently stop working; the poll is the fallback that keeps it working, at the cost of energy.

### A5. AirPods listening mode (noise control and transparency)

What it does: when the user changes listening mode on AirPods, shows a HUD with the mode's symbol for a short timed period.

How it works [verified](reference/atoll/DynamicIsland/managers/BluetoothAudioManager.swift):
- Listens for a list of undocumented distributed notifications and Darwin notifications from the audio accessory and Bluetooth daemons.
- Runs a one-shot `ioreg` read to find the current mode.
- Runs a long-lived `log stream` child process, filtered to messages from the audio accessory, Bluetooth and hearing daemons, matching mode keywords. It is started when the setting is on (default on). [verified](reference/atoll/DynamicIsland/models/Constants.swift line 1264)

Permissions: none declared. Reading other daemons' logs may be restricted on future macOS versions [inferred].

Breakage risk: high. Undocumented notification names, log-message text matching, and a persistent child process. A log-format change silently disables the feature. The log predicate also reads other processes' messages, which is a privacy concern: the stream must never be logged or stored.

DropNotch takeaway: skip for MVP. If added later, make it an opt-in module behind the protocol, with no log streaming.

### A6. Weather and air quality

What it does: shows current conditions, temperature range, optional sunrise and sunset, location name and air-quality index on the lock screen. The weather data itself is shown on the lock screen, which the media/lock-screen analyst covers. This section covers the data path.

Data sources [verified](reference/atoll/DynamicIsland/managers/LockScreenWeatherManager.swift):
- Open-Meteo forecast endpoint for conditions, and a separate Open-Meteo air-quality endpoint for AQI. Open-Meteo is a third-party HTTP API. The request is built from coordinates. No credential is attached in the request construction. [inferred: no key is visible in the request-building code]
- wttr.in as an alternative provider, built from a location query. This is an unofficial third-party service. [verified](reference/atoll/DynamicIsland/managers/LockScreenWeatherManager.swift)
- Default provider: Open-Meteo. [verified](reference/atoll/DynamicIsland/models/Constants.swift line 1093)

Location: CoreLocation when-in-use authorisation, requested with 100-metre accuracy. The last location is reused for up to 30 minutes. [verified](reference/atoll/DynamicIsland/managers/LockScreenWeatherManager.swift lines 1092-1140)

Permission timing: the location-preparation call is made at launch when the weather widget setting is on, and that setting defaults to on. So the Location prompt appears at first launch, before any lock-screen feature is used. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift line 1058; models/Constants.swift line 1080)

Refresh: default interval 30 minutes, refresh on demand. There is no timer in the weather manager. [verified](reference/atoll/DynamicIsland/models/Constants.swift line 1085; managers/LockScreenWeatherManager.swift lines 92-96)

Breakage risk: low for Open-Meteo (a documented public API; commercial terms are [inferred] to need checking). Medium for wttr.in (unofficial, no stability guarantee).

DropNotch takeaway: use Open-Meteo or WeatherKit (Apple's public weather framework, which needs an entitlement and Apple Developer account; [inferred] requirements, verify before use). Ask for Location only when the weather feature is first enabled, not at launch, which is what CLAUDE.md requires. Send coordinates only, and say so in the privacy copy.

### A7. Calendar and reminders

What it does: shows upcoming events and reminders in the notch and on the lock screen. It extracts a conference-call link from an event's URL or notes so the user can join from the notch. It can mark a reminder complete.

Frameworks and APIs (all public, EventKit):
- Full-access requests for events and reminders (the macOS 14 request API). [verified](reference/atoll/DynamicIsland/Providers/CalendarServiceProviding.swift lines 38-60)
- Event fetch by predicate for a date range; reminder fetch with a completion handler. [verified](reference/atoll/DynamicIsland/Providers/CalendarServiceProviding.swift lines 80-130)
- Change notification for the event store, with throttling. [verified](reference/atoll/DynamicIsland/managers/CalendarManager.swift lines 80-130)
- Conference link extraction from the URL and notes text. [verified](reference/atoll/DynamicIsland/Providers/CalendarServiceProviding.swift lines 299-355)

Permissions: Calendars and Reminders (full-access usage keys are present), and the calendars entitlement. [verified](reference/atoll/DynamicIsland/DynamicIsland.entitlements) and the build settings (see C2).

Timers [verified](reference/atoll/DynamicIsland/managers/CalendarManager.swift and ReminderLiveActivityManager.swift):
- Event store changes: refresh throttled to one per 20 s; changes the app itself caused are suppressed for 6 s.
- Reload interval: 15 s.
- Lock-screen calendar refresh loop: wakes every 60 s for the life of the loop and skips the work when calendar access is missing.
- Reminder ticker: 1 s, running only while a reminder activity is active.

When the access request happens: [inferred] the check runs from the calendar manager's setup; whether it fires at launch or only when the calendar feature is first enabled was not confirmed in the source reviewed.

Breakage risk: low. EventKit is public and stable.

DropNotch takeaway: EventKit with the change notification is the right design. Replace the 60 s loop with the change notification, and run the reminder ticker only when a reminder is due within the displayed window, or use a single timer aligned to the next event start.

### A8. CPU, GPU, memory, network, disk and temperature

What it does: a stats panel with live graphs for CPU, GPU, memory, network, disk and temperature, plus a ranked list of processes by CPU or memory.

Frameworks and APIs:
- CPU load and memory: Mach host statistics and sysctl (public). [verified](reference/atoll/DynamicIsland/managers/StatsManager.swift, around lines 795 and 861-863; utils/AppleHardwareInfo.swift lines 76-87)
- GPU utilisation: IORegistry matching on the accelerator class, reading its performance-statistics dictionary. Public IOKit, but the dictionary keys are undocumented. Medium risk. [verified](reference/atoll/DynamicIsland/managers/StatsManager.swift lines 109-140)
- CPU frequency and power: the private IOReport framework, loaded at run time with `dlopen` and symbols looked up by name. Private. High risk. [verified](reference/atoll/DynamicIsland/utils/IOReportBridging.swift lines 24-40; utils/CPUSensorCollector.swift)
- Temperature: the private system management controller service, reading sensor values. Private and chip-specific. High risk. [verified](reference/atoll/DynamicIsland/utils/SMC.swift lines 171-190, 537)

Permissions: none for these data [inferred].

Timers [verified](reference/atoll/DynamicIsland/managers/StatsManager.swift):
- User-set update interval, 1 to 60 s, default 1 s.
- Process list refresh every 2 s.
- Monitoring starts after 0.5 s and stops 3 s after the notch closes; a tab switch stops after 0.1 s.
- Nothing runs while the stats view is not visible [inferred from the start condition, which requires the notch to be open and the stats tab to be current: `reference/atoll/DynamicIsland/managers/StatsManager.swift` line 528].

Breakage risk: high for temperature and frequency (private, chip-specific keys). The IOReport loader fails soft when symbols are missing, which is good. [verified](reference/atoll/DynamicIsland/utils/IOReportBridging.swift)

Attribution: the README credits a third-party stats project for the SMC approach. See C6.

DropNotch takeaway: use public Mach and sysctl for CPU and memory, and keep temperature and frequency out of the MVP. If added, put them behind a protocol with a graceful "not available" state, as CLAUDE.md requires for private APIs.

### A9. Focus and Do Not Disturb state

What it does: shows a Focus indicator in the notch when a Focus mode is on, with the mode's name and symbol where it can read them.

How it works [verified](reference/atoll/DynamicIsland/managers/DoNotDisturbManager.swift):
- Reads the per-user Focus assertions file under the user's Library folder (undocumented location and format) and checks its modification date every 2 s. A DispatchSource timer drives this. [verified](reference/atoll/DynamicIsland/managers/DoNotDisturbManager.swift lines 41-60, 584-640)
- Reads a second configuration file with mode names. That file is protected, so the feature checks readability of the system permissions database to see whether Full Disk Access is granted, and asks the user for it if not. [verified](reference/atoll/DynamicIsland/managers/DoNotDisturbManager.swift lines 1413-1450; helpers/FullDiskAccessPermissionStore.swift lines 23-45)
- An alternative "developer tools" mode streams a system daemon's log and runs a one-shot log query at start. [verified](reference/atoll/DynamicIsland/managers/DoNotDisturbManager.swift lines 520-540)
- Distributed notifications for Focus on and off (underscore-prefixed, private), with a 4-second cooldown. [verified](reference/atoll/DynamicIsland/managers/DoNotDisturbManager.swift lines 59, 91-110)

Permissions: Full Disk Access (optional, for names). The app's own check reads the permissions database, which is itself an undocumented file. [verified]

Default: detection is on by default. [verified](reference/atoll/DynamicIsland/models/Constants.swift line 1461)

Breakage risk: high. Undocumented file formats, private notifications, and a privacy-sensitive permission hack. A minor update can break it without warning.

DropNotch takeaway: skip reading other Focus state. There is no documented public API to read another app's Focus status [inferred]. The Focus filter mechanism lets an app respond to a Focus that the user configured for it, which is a cleaner option if Focus integration is wanted later. Do not ask for Full Disk Access.

### A10. Camera and microphone in-use indicator

What it does: shows a privacy indicator in the notch when the camera or microphone is in use.

Frameworks and APIs:
- Camera: CoreMediaIO object property queries and property listeners that detect a device running. [verified](reference/atoll/DynamicIsland/managers/CameraMonitor.swift lines 150-180). CoreMediaIO is a public framework, but these property selectors are less documented, so medium risk.
- Microphone: CoreAudio device property listener for "is running somewhere" on input devices. Public API. [verified](reference/atoll/DynamicIsland/managers/MicrophoneMonitor.swift lines 185-235)

Permissions: none for detecting in-use state [inferred]. Camera and microphone access are needed only to use those devices, which Atoll does for its own camera and recording features.

Timers: none. Listeners are event-driven. [verified](reference/atoll/DynamicIsland/managers/MicrophoneMonitor.swift)

Breakage risk: low for CoreAudio. Low to medium for CoreMediaIO.

DropNotch takeaway: this is a strong, low-cost, privacy-positive feature. Build the microphone path on CoreAudio listeners first, and add the camera path after testing on a notched Mac.

### A11. Screen recording indicator

What it does: shows a notch indicator while a screen recording is in progress and counts the duration.

How it works [verified](reference/atoll/DynamicIsland/managers/ScreenRecordingManager.swift):
- On app activation and termination events, it runs a child process to check whether the native screen-capture process is running. The check is a process-list lookup by exact name. This spawns a process on each activation.
- While recording, a 1-second timer updates the duration. [verified](reference/atoll/DynamicIsland/managers/ScreenRecordingManager.swift line 463)

Breakage risk: medium. The process name is undocumented, and the check depends on the native tool's name.

DropNotch takeaway: a subprocess per app activation is wasteful. Use the public ScreenCaptureKit stream status where possible, or accept the process check only as a fallback. [inferred: ScreenCaptureKit does not observe the native screenshot tool.] Verify before relying on either.

### A12. Caps Lock indicator

What it does: shows a Caps Lock indicator in the notch when the state changes.

How it works [verified](reference/atoll/DynamicIsland/managers/CapsLockManager.swift lines 41-50): a local and a global event monitor for modifier-flag changes, using the public NSEvent API.

Permissions: [inferred] a global monitor for modifier changes may require Input Monitoring on current macOS. Verify on a clean install before shipping.

Breakage risk: low.

### A13. Keep-awake (caffeinate)

What it does: keeps the Mac awake while a timer or user action is active, and shows a countdown.

How it works [verified](reference/atoll/DynamicIsland/managers/CaffeinateManager.swift lines 100-111, 141): create and release power-management assertions (public IOKit power management), with a 1-second ticker for the countdown.

Breakage risk: low. Public API.

DropNotch takeaway: the assertion API is public and sufficient. The ticker should run only while a countdown is visible.

### A14. Siri visibility (hiding overlays while Siri is on screen)

What it does: hides the lock-screen overlays while Siri's window is visible, so they do not sit on top of it.

How it works [verified](reference/atoll/DynamicIsland/managers/SiriVisibilityMonitor.swift lines 99-200):
- Lists on-screen windows with the public window-list API and looks for Siri's window.
- Polls at an interval chosen by a user setting and by power state: 0.2 s idle and 0.03 s active on high performance (about 33 Hz); 0.5 s idle and 0.06 s active on balanced; 2 s idle and 0.25 s active on power saver.
- Polls only while the screen is locked and the display is on.

Breakage risk: medium. Depends on the window owner name, which is undocumented.

Energy: high. At 33 Hz the window list is read about 33 times a second while Siri is visible on a locked Mac. This is an anti-pattern for DropNotch.

DropNotch takeaway: skip. If Siri hiding is wanted, use a notification-driven approach rather than polling.

### A15. Volume, brightness and keyboard-backlight HUD replacement

What it does: replaces the macOS volume, brightness and keyboard-backlight indicators with the notch HUD. It intercepts the media keys and suppresses the native indicator.

Mechanisms, each labelled:
- Media key capture: an event tap on the session and HID event streams (public CGEventTap API). It requires Accessibility trust. The app prompts for Accessibility when the tap starts, and retries with timers until the tap can be created. [verified](reference/atoll/DynamicIsland/managers/MediaKeyInterceptor.swift lines 148, 158-175, 192-215, 237-285, 464-470)
- Volume: a CoreAudio-based controller (public). [inferred from the imports and file name: `managers/SystemVolumeManager.swift`]
- Display brightness: the private DisplayServices framework, loaded with `dlopen`, with functions resolved by name (private). [verified](reference/atoll/DynamicIsland/helpers/DisplayServicesDynamic.swift lines 34-44)
- Display brightness fallback: a legacy display-connect service lookup (IOKit, deprecated on current hardware), then a private diagnostics command whose plist output is parsed. [verified](reference/atoll/DynamicIsland/managers/SystemDisplayManager.swift lines 27-82)
- Keyboard backlight: the private CoreBrightness framework, loaded with `dlopen` and a runtime class lookup. [verified](reference/atoll/DynamicIsland/managers/KeyboardBrightnessSensor.swift lines 153-175)
- Suppression of the native indicator: it stops the system on-screen-display helper process with a stop signal, and restarts it with the system service manager when disabled. It sends a continue signal on app termination so the native indicator is never left frozen. [verified](reference/atoll/DynamicIsland/managers/SystemOSDManager.swift lines 24-30, 92-160, 183-210)
- A watcher loop polls the process list (150 ms while a new process ID appears, then 500 ms and 1 s) to re-stop any respawned helper. Sleep pauses the loop. [verified](reference/atoll/DynamicIsland/managers/SystemOSDManager.swift lines 371-420, 450-470)

Permissions: Accessibility (for the event tap). The system service manager and process signalling need no permission but are not sandbox-friendly. Atoll is not sandboxed. App Sandbox is switched off in the project settings. [verified](reference/atoll/DynamicIsland.xcodeproj/project.pbxproj)

Breakage risk: high. Freezing a system process is the riskiest technique in the codebase. Every macOS update can change the helper's name, its launch behaviour, or the private frameworks. Any process-freezing feature needs an always-resume safety path [inferred]. [verified](reference/atoll/DynamicIsland/managers/SystemOSDManager.swift lines 173-182)

DropNotch takeaway: do not replicate in the MVP. The public-only alternative is to show DropNotch's own HUD for changes DropNotch itself makes, and to leave the native indicators alone. If system HUD replacement is later wanted, put it behind a protocol with a fallback that does nothing, as CLAUDE.md requires.

### A16. Menu-bar clearance

What it does: when the frontmost app's menus extend into the strip to the left of the notch, moves live-activity content to the right so it does not cover menus. It only shifts content when there is an overlap.

How it works [verified](reference/atoll/DynamicIsland/managers/MenuBarLayout.swift):
- Reads the frontmost app's menu-bar items through the Accessibility API, and takes the right edge of the last item.
- Requires Accessibility trust. It checks trust without prompting. [verified](reference/atoll/DynamicIsland/managers/MenuBarLayout.swift lines 110-114)
- Runs the scan off the main actor, with a 0.25 s per-element messaging timeout and a 1 s scan deadline, so a hung app cannot stall the UI. [verified](reference/atoll/DynamicIsland/managers/MenuBarLayout.swift lines 139-188)
- Polls every 3 s, only while something is tracking the measurement. It also refreshes on app activation. [verified](reference/atoll/DynamicIsland/managers/MenuBarLayout.swift lines 38, 80-100)

Breakage risk: medium. Accessibility geometry is a public API, but cross-process calls can be slow, and the menu-bar tree may change.

DropNotch takeaway: the public notch geometry is enough for the closed notch. Only add this if DropNotch shows content beside the notch. If added, read menu geometry only on demand, not on a timer.

### A17. Full-screen detection

What it does: hides the notch (or only for now-playing apps, depending on a setting) when an app is in native full-screen mode on that display.

How it works [verified](reference/atoll/DynamicIsland/observers/FullscreenMediaDetection.swift):
- A third-party package (MacroVisionKit) reports windows that cover the screen. [verified](reference/atoll/DynamicIsland/observers/FullscreenMediaDetection.swift line 25)
- The result is confirmed with the Accessibility full-screen attribute on the focused window, falling back to the package's answer when Accessibility is not trusted. The attribute is undocumented but long-standing, so [inferred] medium risk. [verified](reference/atoll/DynamicIsland/observers/FullscreenMediaDetection.swift lines 122-140)
- Triggered by active-Space and screen-parameter notifications, with a 500 ms debounce. [verified](reference/atoll/DynamicIsland/observers/FullscreenMediaDetection.swift lines 46-70)
- Default on. [verified](reference/atoll/DynamicIsland/models/Constants.swift line 1053)

Breakage risk: medium (the undocumented attribute; the third-party package's licence is unconfirmed, see C4).

DropNotch takeaway: the public full-screen collection behaviour already keeps the panel visible on full-screen Spaces. Decide whether to hide it, and if so use the public full-screen notifications and the Accessibility attribute only with a fallback.

### A18. Memory watchdog and self-relaunch

What it does: monitors Atoll's own memory footprint and relaunches the app if it exceeds a memory limit.

How it works [verified](reference/atoll/DynamicIsland/managers/MemoryUsageMonitor.swift lines 24-50, 90-120; DynamicIslandApp.swift line 830):
- Polls the task's basic info every 8 seconds, from launch onwards, for the life of the app.
- Relaunches through the public workspace API and terminates, with a 300 s cooldown. Logs a memory sample every 300 s.

Breakage risk: low for the APIs. Poor fit for energy: an always-on 8 s wake-up for a problem that event-driven code should not have.

DropNotch takeaway: do not copy. Fix memory growth with profiling (performance-optimizer), not with a self-relaunch loop.

---

## Part B: App shell

### B1. Notch panel window

What it does: the window that holds the notch. It sits above the menu bar, on every Space, above full-screen apps, and hosts the SwiftUI content.

Construction [verified](reference/atoll/DynamicIsland/components/Notch/DynamicIslandWindow.swift; DynamicIslandApp.swift lines 406-436):
- A subclass of `NSPanel` (public AppKit).
- Style: borderless plus non-activating panel.
- Floating panel; does not hide on deactivate; opaque off; clear background; not movable; no shadow; animation behaviour none; not released on close.
- Level: main-menu level plus 3 (public constant arithmetic). Above the menu bar.
- Collection behaviour: full-screen auxiliary, can join all Spaces, ignores the window cycle, stationary. All public flags.
- The panel can become key and main. This is what lets a text field inside the panel take keyboard input [inferred]. [verified](reference/atoll/DynamicIsland/components/Notch/DynamicIslandWindow.swift lines 63-69)
- The content view is a hosting-view subclass that accepts the first mouse click, so a click works without first activating the window. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 90-95)
- Screen-capture visibility: the `sharingType` of the panel is set to none when the user hides DropNotch from screen capture, otherwise read-only. Public AppKit property. [verified](reference/atoll/DynamicIsland/helpers/ScreenCaptureVisibilityManager.swift lines 20-69)

Click-through: there is no `ignoresMouseEvents` on the notch window. [verified by absence in DynamicIslandApp.swift and DynamicIslandWindow.swift; the flag appears only on lock-screen windows.] Instead the window is resized to the size of the current content, so a closed notch covers only a notch-sized rectangle and clicks elsewhere reach the apps underneath. [inferred from the resize path, verified at reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 631-670, and the closed-size logic in the notch sizing routine]

Activation policy: the app switches to a regular activation policy (Dock icon visible) when Settings, onboarding or a camera alert is shown, and back to accessory afterwards. [verified](reference/atoll/DynamicIsland/components/Settings/SettingsWindowController.swift lines 125-146; DynamicIslandApp.swift lines 1628, 1645; models/DynamicIslandViewModel.swift lines 502-511)

Permissions: none.

Breakage risk: low. All flags are public.

DropNotch takeaway: this matches the MVP requirement for a borderless, non-activating panel with a high level. Resize the window to the content rather than keeping a large transparent window and toggling ignore-mouse, which is simpler and avoids stealing clicks. Confirm on device that a click on a closed-notch area in a full-screen app is not swallowed.

### B2. Pinning to all Spaces (private)

What it does: keeps the notch on top of every Space and of full-screen Spaces, using a private window-server "Spaces" object at the maximum absolute level, to which the notch windows are added.

How it works [verified](reference/atoll/DynamicIsland/private/CGSSpace.swift lines 26-87; managers/NotchSpaceManager.swift lines 25-33; DynamicIslandApp.swift lines 381-395, 434):
- A small wrapper creates a private Space, sets its absolute level to the maximum, shows it, and adds or removes windows from it. The Spaces functions are bound by underscore-prefixed symbol names at link time. [verified](reference/atoll/DynamicIsland/private/CGSSpace.swift lines 69-87)
- Private-space setup is fragile and any use must be tested on device [inferred].
- The membership is re-synchronised on every Space change and screen change. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 395-405)

Permissions: none, but this is a private API.

Breakage risk: high. Private functions bound at link time. [inferred: a missing symbol in a future macOS version would fail at launch, not at run time, so there would be no graceful fallback.] The same private window-server approach is reused by the lock-screen and HUD windows (see C4), so a break would spread beyond the notch. A window-server change could also alter behaviour silently.

DropNotch takeaway: do not use in the MVP. The public collection behaviour from B1 (all Spaces, full-screen auxiliary, high level) is what the MVP specification asks for. If a gap is observed on device, record it in docs/RISKS.md and use a protocol with a fallback.

### B3. Notch geometry

What it does: works out the notch's width and height, and where to place the window at the top of the screen.

Public APIs used [verified](reference/atoll/DynamicIsland/sizing/matters.swift):
- `safeAreaInsets` on the screen: a top inset above zero means a notch is present. Public, macOS 12 and later. [verified](reference/atoll/DynamicIsland/sizing/matters.swift line 350; DynamicIslandApp.swift lines 1500-1502)
- `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`: the usable menu-bar regions either side of the notch. Public, macOS 12 and later. [verified](reference/atoll/DynamicIsland/sizing/matters.swift lines 411-412)

Width: the screen width minus both auxiliary widths, plus an empirical correction (value not recorded here), unless the user sets a custom width. [verified](reference/atoll/DynamicIsland/sizing/matters.swift lines 397-420).

Height: one of three modes, chosen per display type. One takes the height from the physical notch (the top inset). One takes it from the menu bar (the difference between the full frame top and the visible-frame top). A fixed height is the fallback. [verified](reference/atoll/DynamicIsland/sizing/matters.swift lines 422-430; models/Constants.swift lines 989-998)

Placement: the window's top edge sits on the screen's top edge, plus a small bleed on notch displays so the window overlaps the menu bar's top pixel row. In pill style there is no bleed and the pill sits a few points below the top edge. DropNotch tunes its own values on device. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 439-460; sizing/matters.swift lines 362-371)

Rounding: the top inset can be fractional on some hardware, so frames need rounding. Measure on DropNotch's own displays. [verified](reference/atoll/DynamicIsland/managers/LockScreenLiveActivityWindowManager.swift line 63)

Breakage risk: low. Public API. The constants are empirical and may need tuning per model.

DropNotch takeaway: use `safeAreaInsets` and the auxiliary areas exactly as the MVP specifies. Use rounding, and tune the bleed and offset on device.

### B4. Non-notch and external display style

What it does: on a display without a notch (an external monitor, or a notch-less Mac), either draws the notch-shaped panel or a rounded "pill" shape, and optionally hides it until the pointer reaches the top edge.

Settings and defaults [verified](reference/atoll/DynamicIsland/models/Constants.swift lines 984-1001):
- External-display style: notch by default, with a pill option.
- Non-notch height: taken from the menu bar by default.
- Hiding the closed view until the pointer reaches the top edge: off by default.

Pill style [verified](reference/atoll/DynamicIsland/sizing/matters.swift lines 320-352): applies only when the user chose the pill style and the display has no notch. Corner radii and shadow insets are constants.

Reveal at the top edge: the closed view is kept out of sight on non-notch displays, and a fast hover loop (50 ms) checks whether the pointer is over a hit rectangle at the top edge to reveal it. The effective closed height is zero while hidden. [verified](reference/atoll/DynamicIsland/ContentView.swift lines 431-440, 2075-2150; models/DynamicIslandViewModel.swift lines 376-380)

Breakage risk: low for geometry. Medium for revealing at the top edge, because it is driven by a 50 ms poll.

DropNotch takeaway: the MVP's fallback pill is the right idea. Do not implement reveal-at-the-top-edge by polling. A top-edge tracking area or a global mouse-moved monitor is event-driven, but it needs care; flag it for performance-optimizer and test on device.

### B5. Multi-display

What it does: shows the notch on one chosen display, on the main display, or on every display.

Modes [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 1528-1590; models/Constants.swift lines 974-975):
- Single display (default): one window, placed on the preferred display chosen by name. If none is chosen and automatic switching is on (default on), it follows the main display.
- All displays: one window and one view model per display, created and removed as displays come and go. The views are keyed by the screen object. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 1528-1560)

Identity: many places identify a display by its localised name rather than a stable display ID. Examples: `sizing/matters.swift` lines 82, 341 and 387; `ContentView.swift` line 415; `DynamicIslandApp.swift` line 1562. Two identical monitors can share a name and collide [inferred]. The two modes also use different identities (name in one, screen object in the other), which is a maintenance hazard. Atoll uses the built-in display check and the main display ID elsewhere. [verified](reference/atoll/DynamicIsland/managers/LockScreenDisplayContextProvider.swift lines 75-85)

Settings: the display picker lists names and refreshes when the screen list changes. [verified](reference/atoll/DynamicIsland/components/Settings/SettingsView.swift lines 1119, 1196-1213)

Breakage risk: medium. Identity by name is fragile, and the dual identity is error-prone.

DropNotch takeaway: key every per-display object by a stable display ID (the screen's device-description display number, a public key) and never by localised name. Keep the MVP to "one display, main by default", and add all-displays as a second step.

### B6. Screen and Space change handling

What it does: rebuilds or repositions windows when displays are added, removed or rearranged, and re-asserts membership after a Space change.

Handling [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift):
- Screen parameter change: compares the new list of screens with the previous list (by name set and frame set) and, if different, tears down and rebuilds windows on the next main-queue turn. No debounce. (handler at lines 1509-1525; observer at line 923)
- Active Space change: re-asserts Space membership and collection behaviour, then repositions. (lines 925-937, 395-405)
- Screen lock and unlock: hides the windows on lock and restores them one second after unlock. The signals are distributed notifications with names that are not in Apple's public documentation [inferred]. (observers registered at lines 977-982; handlers at lines 310 and 324-360)

Breakage risk: low for the public notifications; medium for the undocumented lock notifications (they have been stable for years, but are not documented).

DropNotch takeaway: use the public screen-parameter and Space-change notifications, add a short debounce (100 to 300 ms) because display changes arrive in bursts, and for lock state use the public session notifications or the lock-screen state from the lock-screen module.

### B7. Hover, click, expand and collapse

What it does: opens the notch on hover after a short delay, or on click, and closes it when the pointer leaves. It supports a keyboard shortcut and a two-finger gesture.

Hover detection [verified](reference/atoll/DynamicIsland/ContentView.swift):
- SwiftUI hover on the notch shape, plus a fallback polling loop that hit-tests the pointer against the notch rectangle. SwiftUI hover can be unreliable at the top screen edge; confirm on device [inferred]. (lines 437-439, 2113-2150, 2075-2097, 2336-2360)
- The hit rectangle is widened while hovering, and includes a small margin. The top-edge pixel row is treated as inside, using an inclusive edge test in the same file. (lines 2336-2360, and the helper that follows them)

Opening: a hover opens the notch after the minimum hover duration (default 0.3 s), unless a HUD is up, a recording is active, or hover-open is suppressed. [verified](reference/atoll/DynamicIsland/ContentView.swift lines 2247-2300; models/Constants.swift line 980)

Click: while hovering, a global and a local left-mouse-down monitor open the notch. Both are public NSEvent APIs. Mouse-down monitors do not need a permission [inferred], to verify on device. (lines 2156-2200)

Closing: leaving the area starts a 100 ms debounce; hover is retained while the pointer is on the screen's top pixel row. The terminal tab has a separate outside-click monitor. (lines 2247-2347)

Open and close [verified](reference/atoll/DynamicIsland/models/DynamicIslandViewModel.swift lines 395-460): a two-state model (closed and open). Opening computes the target size and asks the app delegate to resize the window. Closing returns to the closed size and resets to the home view, or to the tray if it has files and the user opted in.

Animation [verified](reference/atoll/DynamicIsland/ContentView.swift around 2270-2290; DynamicIslandApp.swift lines 651-670):
- Content uses SwiftUI animations of the bouncy and smooth kinds, with a speed factor.
- The window frame is set directly with no AppKit animation; the resize function accepts an animated flag but does not use it. The content animates while the window jumps to its target size.
- Haptic feedback on hover over the notch when the setting is on.

Timers: a 3-second auto-close after a keyboard-opened notch [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift, toggle handler); a short auto-close for the first-launch welcome view [verified](reference/atoll/DynamicIsland/models/DynamicIslandViewModel.swift line 476); a 2-second reset of a camera-request flag [verified](reference/atoll/DynamicIsland/models/DynamicIslandViewModel.swift line 518).

Breakage risk: medium. Hover and click behaviour across displays and full-screen apps needs device testing. The hover loop is an energy cost (see section 3).

DropNotch takeaway: adopt the open and close state model, the hover delay, and the click path. Replace the 1 Hz hover loop with event-driven tracking (tracking areas plus a global mouse-moved monitor only while the pointer is near the notch). For the frame jump, size the window to the larger of the two states before animating the content, so nothing is clipped.

### B8. Settings window

What it does: a standard settings window hosting the SwiftUI settings view.

Construction [verified](reference/atoll/DynamicIsland/components/Settings/SettingsWindowController.swift lines 27-146; DynamicIslandApp.swift lines 50-88):
- An `NSWindow` with titled, closable, miniaturisable, resizable and full-size-content styles, a unified toolbar, normal level, managed collection behaviour, and a hosting view for SwiftUI.
- Screen-capture visibility limited to panels.
- Replaces the standard app Settings menu command with one that opens this window.
- Activation policy is switched to regular while the window is open and back to accessory on close.

Breakage risk: low. Public API.

DropNotch takeaway: a plain window is right. Keep the activation policy switch, because an accessory app needs it to show a window that accepts keyboard input.

### B9. Menu bar item

What it does: a menu-bar icon whose menu holds settings, an update check, a restart and a quit item, plus a setting to hide the icon.

Construction [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 50-88): a SwiftUI menu-bar extra (public, macOS 13 and later), inserted or removed by a user default. The menu holds a settings item, an update-check item, a restart item (which launches a new instance through the public workspace API and then quits) and a quit item with the standard command shortcut.

Dead code: a separate AppKit status-item class exists but nothing instantiates it. [verified](reference/atoll/DynamicIsland/menu/StatusBarMenu.swift; no construction site found in the source) Do not copy it.

Breakage risk: low.

DropNotch takeaway: use the SwiftUI menu-bar extra as the MVP requires. The MVP needs Settings and Quit; the update check item depends on C5.

### B10. Agent app (no Dock icon)

What it does: keeps the app out of the Dock and the Command-Tab switcher.

Construction [verified](reference/atoll/DynamicIsland.xcodeproj/project.pbxproj lines 810 and 885): the agent-app key is generated from a build setting (`INFOPLIST_KEY_LSUIElement`) rather than written in the Info.plist. The committed Info.plist does not contain the key. Runtime switches are in B1 and B8.

Breakage risk: low. Public key.

DropNotch takeaway: set the key in `project.yml` as the CLAUDE.md requires, and check that the generated plist has it.

### B11. Launch at login

What it does: a toggle in Settings for starting the app at login.

Construction [verified](reference/atoll/DynamicIsland/components/Settings/SettingsView.swift lines 13, 1196-1199): a toggle from a third-party package (LaunchAtLogin-Modern), used directly in the settings view. [inferred: the package wraps the public login-item service that is available on macOS 13 and later.] The first use may show a system notification about the login item.

Permissions: none. [inferred]

Dependency note: the package is pinned to a branch, not a version (see C4), which conflicts with the CLAUDE.md rule to pin with an exact version.

Breakage risk: low.

DropNotch takeaway: use the public login-item service directly, or a package pinned to an exact version after dependency-manager has reviewed it. Adding a dependency needs Shash's approval.

### B12. Timers and polling in the shell

Each row is verified unless marked. "Default" is the default setting value.

| Timer or loop | Interval | Gating | Where | Notes |
|---|---|---|---|---|
| Notch hover loop | 1 s idle; 100 ms when hovering; 50 ms while the closed view is kept out of sight | Runs for the life of the notch content view | `ContentView.swift` 2113-2150 | Always on, including idle. Largest shell energy cost. |
| Hover open delay | 0.3 s (default) | One-shot, on hover | `ContentView.swift` 2286 | Cancelled on exit. |
| Hover exit debounce | 100 ms | One-shot | `ContentView.swift` 2305 | Fine. |
| Menu-bar clearance scan | 3 s | Only while tracking; refresh on app activation | `MenuBarLayout.swift` 38, 80-100 | Off-main-actor, 1 s deadline. |
| Memory watchdog | 8 s | From launch, always | `MemoryUsageMonitor.swift` 32, 46; `DynamicIslandApp.swift` 830 | Anti-pattern (A18). |
| Bluetooth device poll | 3 s | Unconditional from init | `BluetoothAudioManager.swift` 134, 253-260 | Anti-pattern for DropNotch (A3). |
| Bluetooth battery caches | 5 s, 20 s, 30 s | Triggered by events and polls | `BluetoothAudioManager.swift` | Subprocess cost (A3). |
| Listening-mode log stream | Continuous child process | When the setting is on (default on) | `BluetoothAudioManager.swift` 230-251 | Skip (A5). |
| Siri visibility poll | 0.03 to 2 s | Only while locked and display on | `SiriVisibilityMonitor.swift` 99-158 | Up to ~33 Hz (A14). |
| HUD suppression watcher | 150 ms, 500 ms, 1 s (backoff); 1 s while asleep | Continuous while HUD replacement is on | `SystemOSDManager.swift` 382-420 | Process-list read per tick (A15). |
| Focus file poll | 2 s (1 s lead) | When Focus detection is on (default on) | `DoNotDisturbManager.swift` 584-595 | File-date check (A9). |
| Screen-recording duration | 1 s | While recording | `ScreenRecordingManager.swift` 463 | Fine. |
| Caffeinate countdown | 1 s | While active | `CaffeinateManager.swift` 141 | Fine if gated. |
| Stats monitoring | 1 to 60 s (default 1 s); process list 2 s | Only while the stats view is visible; stops 3 s after the notch closes | `StatsManager.swift` 458-467, 532, 583-660 | Good gating. |
| Calendar lock-screen loop | 60 s | While the calendar lock-screen feature is enabled | `CalendarManager.swift` 347-357 | Could use the change notification. |
| Calendar reload | 15 s; event-store throttle 20 s | On change | `CalendarManager.swift` 48-124 | Good. |
| Reminder ticker | 1 s | Only while a reminder is active | `ReminderLiveActivityManager.swift` 423-436 | Good. |
| Weather refresh | 30 min (default) | On demand; no timer | `LockScreenWeatherManager.swift` 92-96 | Good. |
| Battery change | Event (run-loop source) plus 1 s queue drain | Event-driven | `BatteryActivityManager.swift` 76-130, 205 | Good. |
| Full-screen detection | Event with 500 ms debounce | On Space or screen change | `FullscreenMediaDetection.swift` 46-70 | Good. |

Summary of energy issues to avoid in DropNotch: the 1 Hz hover loop, the 8 s memory watchdog, the 3 s Bluetooth poll, the 33 Hz Siri poll, and the always-on OSD watcher. These should be the first things performance-optimizer checks against DropNotch's design.

---

## Part C: Project-wide

### C1. Entitlements

The entitlements file contains the following [verified](reference/atoll/DynamicIsland/DynamicIsland.entitlements):

| Key (Apple name) | Value | Purpose in Atoll | Note for DropNotch |
|---|---|---|---|
| Library validation disabled (hardened-runtime exception) | true | Allows loading the bundled MediaRemote adapter framework, which is not signed by the app's team [inferred] | Weakens hardened runtime. Avoid unless the private dependency needs it. security-auditor to review. |
| Camera | true | Webcam mirror | Media/tray analyst's domain. Not needed for MVP. |
| Mach services (an XPC service name) | one name | Extension XPC host | Not needed for MVP. |
| Apple Events automation | true | Controls music apps and Notes | Needed only if DropNotch uses AppleScript. Prefer public app intents or MusicKit where possible. |
| Apple Events temporary exceptions | three third-party apps and Notes | Lets Atoll send events to these apps | Temporary exceptions are discouraged by Apple [inferred]. Avoid. |
| Mach lookup temporary exceptions | two names based on the bundle identifier | Extension service lookup | Avoid. |
| Calendars (personal information) | true | EventKit | Needed for A7. |

Sandbox: App Sandbox is disabled and the hardened runtime is on. [verified](reference/atoll/DynamicIsland.xcodeproj/project.pbxproj lines 791-792, 866-867). Atoll is not sandboxed, which the private APIs and process control require. This is consistent with CLAUDE.md's "not on the Mac App Store" stance [inferred].

### C2. Usage-description and permission keys

Atoll declares these keys. Only the key names and purpose are recorded; the wording is not reproduced.

In the committed Info.plist [verified](reference/atoll/DynamicIsland/Info.plist):
- Apple Music usage (animated artwork).
- Audio capture usage (live spectrum).
- Screen capture usage (screenshots for an assistant feature).
- App Transport Security set to allow arbitrary loads. This turns off ATS for the whole app. See C5.

In the build settings, which the generator merges into the Info.plist [verified](reference/atoll/DynamicIsland.xcodeproj/project.pbxproj lines 806-900):
- Reminders (full access and legacy).
- Calendars (full access and legacy).
- Location (when in use and legacy).
- Microphone.
- Camera.
- Bluetooth (always).
- Apple Events (automation).
- Desktop, Documents and Downloads folders.
- The application category and Metal capture build settings are also set (values not recorded here), and the agent-app key described in B10.

Permission inventory for the shell and system features:

| Permission | Used by | When requested in Atoll | DropNotch rule |
|---|---|---|---|
| Accessibility | Media keys (A15), menu clearance (A16), full-screen confirmation (A17) | Prompted when the media-key tap starts, which is at startup [verified](reference/atoll/DynamicIsland/managers/MediaKeyInterceptor.swift lines 164-173) | Ask only when the feature is first enabled. |
| Location | Weather (A6) | Launch, if weather is on (default on) [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift line 1058) | Ask on first enable, not at launch. |
| Calendars and Reminders | A7 | On check [inferred timing] | Ask on first enable. |
| Bluetooth | A3, A4 | Implicit on first IOBluetooth use [inferred] | Ask on first enable. |
| Full Disk Access | Focus names (A9) | Probed, and the user is directed to grant it [verified](reference/atoll/DynamicIsland/helpers/FullDiskAccessPermissionStore.swift) | Do not request. |
| Apple Events | Music apps and Notes (outside this file) | Automation prompt on first use [inferred] | Only if needed. |

### C3. Deployment target

The app target's deployment target is 14.6 in the project file, while some other targets are 15.0 or 14.0. [verified](reference/atoll/DynamicIsland.xcodeproj/project.pbxproj lines 574, 595, 620, 647, 712, 769, 830, 905) The Atoll appcast minimum is 14.6. [verified](reference/atoll/Updates/appcast.xml) DropNotch's target of macOS 14.0 is lower than Atoll's app target. Test the 14.0 floor for any API that Atoll raised to 14.6 or 15.0 (for example the notch geometry and EventKit full-access calls, which are available from 14.0).

### C4. Third-party packages

Pins are from the committed resolution file [verified](reference/atoll/DynamicIsland.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved). Licences are [inferred] from upstream knowledge and must be confirmed by `dependency-manager` before DropNotch adds any of them (CLAUDE.md, rule 4). Atoll's own licence is GPL-3.0, so nothing here can be copied into DropNotch on its say-so.

| Package | Pin in Atoll | Used for | Shell or system relevance | Licence (inferred) | Notes |
|---|---|---|---|---|---|
| Sparkle | 2.7.0 | Updates | C5 | MIT, with bundled components under other licences | Use with an exact version. |
| Defaults | 9.0.3 | Settings storage | All | MIT | Pin exactly. |
| KeyboardShortcuts | 2.3.0 | Global hotkeys | B7 | MIT | Pin exactly. |
| LaunchAtLogin-Modern | branch main | Login item | B11 | MIT | Branch pin; replace with an exact version. |
| lottie-spm | branch main | Lottie runtime | Animations (other analysts) | Apache-2.0 | Branch pin. Not needed for MVP. |
| LottieUI | branch main | Lottie wrapper | Animations | Unknown; check | Branch pin. Not needed for MVP. |
| Pow | 1.0.5 | SwiftUI effects | None | MIT | No import found in the source. Candidate for removal. [verified by search] |
| open-meteo (package) | 1.4.16 | Weather client | A6 | Unknown; check | Pinned but no import found. The app calls the HTTP API directly. [verified by search] |
| SkyLightWindow | branch main | Wrapper around a private window-server framework, used to move auxiliary windows into a private Space | Lock-screen, full-screen artwork, and HUD/flyout windows (the notch window's own call is commented out) | Unknown; check | Private framework. Fourteen call sites in twelve files. [verified: `DynamicIslandApp.swift` and `managers/*WindowManager.swift`, `managers/FlyoutWindowPresenter.swift`] |
| MacroVisionKit | 0.1.0 | Full-screen detection | A17 | Unknown; check | Third-party. |
| An Atoll-internal extension package | branch main | Extension framework, not evaluated | Extensions | Unknown; check | Branch pin. |
| SwiftTerm | 1.13.0 | Terminal | Utilities (other analyst) | MIT [inferred] | Pin exactly. |
| swift-collections | 1.1.4 | Data structures | Several | Apache-2.0 [inferred] | Pin exactly. |
| swift-argument-parser | 1.7.1 | CLI parsing | Probably transitive | Apache-2.0 [inferred] | Only if needed. |
| swift-syntax | 601.0.1 | Macro support | Probably transitive | Apache-2.0 [inferred] | Only if needed. |
| swiftui-introspect | 1.3.0 | SwiftUI bridging | Settings | MIT [inferred] | Pin exactly. |

Notes:
- Several pins track branches. That is a reproducibility risk, and the CLAUDE.md rule requires exact versions in `project.yml` (the resolution file is gitignored in DropNotch's layout).
- The shell, system and media features depend mostly on Apple frameworks. DropNotch's MVP needs only Sparkle (for updates) and possibly a hotkey library, both to be approved by Shash.

### C5. Update mechanism

What it does: checks for and installs new versions with Sparkle, using a feed chosen by the user's update channel.

Details [verified]:
- Feed URL is chosen at run time from the user's channel. Channels: stable, beta, alpha and nightly. [verified](reference/atoll/DynamicIsland/services/AtollUpdaterDelegate.swift lines 24-28; models/UpdateChannel.swift)
- Four appcast files in the repository's `Updates/` folder, one per channel. The stable feed includes delta items against earlier versions. Each item carries an EdDSA signature. [verified](reference/atoll/Updates/appcast.xml, appcast-alpha.xml, appcast-beta.xml, appcast-nightly.xml)
- The Info.plist declares the default feed location, the public EdDSA key, and enables Sparkle's downloader and installer-launcher XPC services. [verified](reference/atoll/DynamicIsland/Info.plist)
- Automatic check and automatic download toggles are in Settings. [verified](reference/atoll/DynamicIsland/components/Settings/SoftwareUpdater.swift lines 26-82)
- Updates are not started during UI tests. [verified](reference/atoll/DynamicIsland/DynamicIslandApp.swift lines 40-46)

Risks:
- The feeds are served from the source repository's raw file host on the main branch. This is a single point of failure and a supply-chain consideration. [inferred] DropNotch should host appcasts on a release-controlled HTTPS location and sign the archives with EdDSA.
- ATS is disabled for the whole app. This is not needed for Sparkle, which uses HTTPS. [inferred] DropNotch should not set arbitrary loads.
- Sparkle's installer XPC services are enabled. That is the recommended Sparkle 2 configuration for sandboxed apps; for an unsandboxed app it is optional [inferred].

Breakage risk: low. Sparkle is a public, widely used framework.

### C6. NOTICE and lineage

What is declared [verified](reference/atoll/NOTICE):
- The NOTICE says the product includes software derived from boring.notch, licensed GPL-3.0, and states it was modified.
- The NOTICE covers a LottieFiles animation under the Lottie Simple License.

What the shell code says [verified](reference/atoll/DynamicIsland/components/Notch/DynamicIslandWindow.swift lines 5-7): file headers name Boring Notch as their origin.

What the README says [verified](reference/atoll/ReadMe.md lines 102-126): it credits Boring Notch as the base of the app, and credits several other projects for design ideas, code it adapted (an audio library for the visualiser, a terminal library, a stats project for temperature reading), the lock-screen window package (SkyLightWindow), and third-party APIs (weather, pricing, usage tracking). See the README by path for the exact list; the wording isn't reproduced here.

Gap: the NOTICE file names boring.notch and a Lottie file only. It does not name the stats project, DynamicNotch, rtaudio, SwiftTerm (MIT [inferred]), SkyLightWindow or Open-Meteo, even though the README says code or assets were adapted from some of them. [verified by comparison] This matters because CLAUDE.md requires DropNotch's licence to remain MIT or GPL-3.0 compatible, and because a GPL-3.0 derivation chain exists for the shell and notch code.

Policy for DropNotch: no code, assets, strings or closely paraphrased structure from Atoll, Boring Notch or any of the above. Techniques from this analysis (public APIs, window configuration, geometry) are general knowledge and are recorded in our own words. Record the lineage question in `docs/DECISIONS.md` and ask Shash to decide before any dependency from this list is added.

---

## Part D: Feature index (one page)

DropNotch has no README in the repository yet. [verified: no README.md at the repository root; `git ls-files` lists none] The feature list below is taken from DropNotch's own task list (TASK.md, the main-screen and lock-screen bullets) and CLAUDE.md's MVP list, and is cross-checked against the Atoll README's Highlights and Other Features sections. Each feature is mapped to the analyst file that covers it. Where the mapping is an assumption, it is marked.

| Feature | One-line description | Covered by |
|---|---|---|
| Now playing (song icon left, waveform right) | Shows track artwork and a live waveform when music plays. | atoll-media-lockscreen.md |
| Hover to expand | Opens the notch on hover after a short delay, or on click. | atoll-system-shell.md (B7) |
| User-chosen calendar or notes panel | Lets the user choose which panel the expanded notch shows. | atoll-system-shell.md (B7) for the switch; atoll-tray-clipboard-utilities.md for notes |
| File tray with AirDrop | Holds dropped files and sends them by AirDrop. | atoll-tray-clipboard-utilities.md |
| Timer | Countdown and stopwatch in the notch. | atoll-tray-clipboard-utilities.md |
| Quick notes | Short notes panel. | atoll-tray-clipboard-utilities.md |
| Terminal | A terminal tab. | atoll-tray-clipboard-utilities.md |
| Clipboard history | History of copied items. | atoll-tray-clipboard-utilities.md |
| Mac battery | Charge and charging state. | atoll-system-shell.md (A1, A2) |
| AirPods battery with connect animation | Device battery and a connect HUD. | atoll-system-shell.md (A3, A4) |
| Animals when nothing is playing (DropNotch's own idea, from TASK.md) | Idle animation on the left when no music plays. | Not confirmed in Atoll [inferred] |
| Lock screen: Mac battery | Battery widget on the lock screen. | atoll-media-lockscreen.md for rendering; atoll-system-shell.md (A1) for data |
| Lock screen: audio-device battery | Bluetooth battery widget on the lock screen. | atoll-media-lockscreen.md for rendering; atoll-system-shell.md (A3) for data |
| Lock screen: AQI | Air quality on the lock screen. | atoll-system-shell.md (A6) for data; atoll-media-lockscreen.md for rendering |
| Lock screen: temperature | CPU or ambient temperature. | atoll-system-shell.md (A8) for data; atoll-media-lockscreen.md for rendering |
| Lock screen: full-screen now playing | Full-screen artwork and controls on lock. | atoll-media-lockscreen.md |
| Weather | Conditions and location on the lock screen. | atoll-system-shell.md (A6) |
| Calendar events | Upcoming events in the notch and lock screen. | atoll-system-shell.md (A7) |
| Reminders | Due reminders with completion. | atoll-system-shell.md (A7) |
| System stats (CPU, GPU, memory, network, disk) | Live graphs and process list. | atoll-system-shell.md (A8) |
| Focus indicator | Shows the active Focus mode. | atoll-system-shell.md (A9) |
| Privacy indicators (camera, microphone) | Indicator when the camera or microphone is in use. | atoll-system-shell.md (A10) |
| Screen recording indicator | Indicator and duration while recording. | atoll-system-shell.md (A11) |
| Caps Lock indicator | Indicator when Caps Lock changes. | atoll-system-shell.md (A12) |
| Keep awake | Prevents sleep for a set time. | atoll-system-shell.md (A13) |
| Volume and brightness HUD | Notch HUD in place of the system indicator. | atoll-system-shell.md (A15) |
| Lyrics | Synced lyrics. | atoll-media-lockscreen.md (assumed; confirm) |
| Gesture controls (open and close) | Two-finger swipe to open and close. | atoll-system-shell.md (B7) for open and close; atoll-media-lockscreen.md for music gestures (assumed) |
| Multiple displays and non-notch screens | Notch on any display; pill style. | atoll-system-shell.md (B4, B5) |
| Launch at login and menu-bar icon | Login item and menu-bar item with Settings and Quit. | atoll-system-shell.md (B9, B11) |
| Updates | Sparkle updates by channel. | atoll-system-shell.md (C5) |
| Colour picker | Picks colour from the screen. | atoll-tray-clipboard-utilities.md (assumed; confirm) |
| Webcam mirror | Camera preview in the notch. | atoll-tray-clipboard-utilities.md |
| Other Atoll extras (not planned for DropNotch) | Not analysed. | — |
| LLM usage | Usage tracking for AI tools. | atoll-tray-clipboard-utilities.md |
| Downloads | Download progress. | atoll-tray-clipboard-utilities.md |
| Smaller notch layout option | A reduced layout. | atoll-system-shell.md (B1, B7 for layout effects); atoll-media-lockscreen.md for content |

---

## Five-line summary for DropNotch

1. Build on public APIs first: the notch panel (borderless, non-activating `NSPanel`, high level, all-Spaces and full-screen-auxiliary behaviour), `safeAreaInsets` and the auxiliary areas for geometry, IOKit power sources for battery, EventKit for calendar and reminders, and Open-Meteo with Location for weather. Atoll uses the same public APIs for these; that is a reference point, not a licence to copy.
2. Keep private and undocumented APIs out of the MVP: the Spaces wrapper (B2), AirPods listening mode (A5), Bluetooth per-bud battery (A3), Focus-state reading (A9), IOReport and SMC (A8), and native HUD suppression by freezing the system OSD helper (A15). Each needs a protocol and a fallback if added later.
3. Energy is the main place to differ from Atoll: its hover loop wakes at 1 Hz for the life of the view, and it has an 8 s memory watchdog, a 3 s Bluetooth poll and a 33 Hz Siri poll. DropNotch should be event-driven by default (tracking areas, IOPS run-loop source, EventKit change notifications, `NSWorkspace` notifications), with each timer justified in `docs/ARCHITECTURE.md`.
4. Multi-display: Atoll supports a single display (default, following the main screen), all displays, and a pill style for non-notch screens. It identifies screens by localised name, which is fragile. DropNotch should key per-display state by a stable display ID and ship single-display first.
5. Project hygiene: Atoll asks for Location at launch by default, pins several packages to branches, disables App Sandbox and ATS for the whole app, uses temporary entitlement exceptions, and its NOTICE omits several credited sources. DropNotch should request each permission on first enable, use exact package versions, set no arbitrary loads, avoid temporary exceptions, and record the full lineage in `docs/DECISIONS.md` before any dependency is added. Requires macOS 14.0 or later; test the 14.0 floor because Atoll's app target is 14.6.

Not covered here (by design): media controllers, lock-screen panel rendering, file tray, clipboard, terminal, notes, LLM usage, colour picker and webcam. These are in the two sibling analyst files. The sibling-file mapping for items outside this file's scope is an assumption until those files are checked against their headings.
