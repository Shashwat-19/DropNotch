# Atoll: tray, clipboard and utility features (clean-room notes)

> Tagging rule: a verified or inferred tag on a heading or a lead-in line applies to every bullet under it, until another tag overrides it. Lines under "Gaps", "Method" or "What I did not check" describe the analysis itself, not the app.

Analyst: reference-analyst. Date: 2026-10-24.
Source studied: `reference/atoll`, tag `v2.3.3-alpha.4`, commit `2e15e5f` (GPL-3.0). Read only. Nothing was built, run or copied.
Path convention: `DynamicIsland/...` means `reference/atoll/DynamicIsland/...`.

Scope: file tray, AirDrop and share sheet (plus the LocalSend peer transfer that sits in the same folder), clipboard history, notes, timers, terminal, caffeinate, per-app volume, keyboard shortcuts, media-key interception and system HUD replacement, extension RPC/XPC server, Shortcuts/App Intents/URL entry points. Media, lock screen, battery, Bluetooth, weather, calendar and windowing are covered by other analysts and only touched here where they overlap.

Tags used below:
- **[verified]** seen in source or README; path and line given so it can be checked.
- **[inferred]** my reasoning from the source or from general knowledge of the Apple platform. Not confirmed in the code or on a page I read.

Breakage risk scale: **low** (public API, stable behaviour), **medium** (public API but behaviour or permissions shift between macOS releases, or a fragile workaround on a public API), **high** (private or undocumented mechanism, or a scraping/process-control trick).

---

## Summary table

| Feature | Main mechanism | Public or private | Permissions | Timer / polling | Breakage risk |
|---|---|---|---|---|---|
| File tray | Drag/drop, bookmarks, temp copies, JSON file | Public | None special; TCC folder prompts still apply [inferred] | Marquee autoscroll at 60 Hz only during drag selection | Medium |
| AirDrop / share | NSSharingService and NSSharingServicePicker | Public (picker harvesting is a workaround) | User action only | 2 s timeout when harvesting services | Low to medium |
| LocalSend transfer | Network.framework UDP multicast, TCP listener, HTTP(S) probing | Public APIs, third-party protocol | Local network access [inferred] | Announce 8 s, cleanup 15 s, subnet probing | Low technically; security high |
| Clipboard history | NSPasteboard changeCount polling | Public | Pasteboard read prompts on newer macOS [inferred] | 0.5 s repeating timer on main run loop | Low for polling; medium for reads |
| Notes | Defaults-backed list, optional Apple Notes sync via AppleScript | Public (AppleScript to Notes) | Automation for Notes | 1.5 s autosave debounce | Medium |
| Own countdown timer | In-app countdown | Public | None | 1 s repeating timer | Low |
| Clock-app timer follower | Log stream, file watch, Accessibility scraping, AX press | Private/undocumented | Accessibility | 1 s ticker fallback | High |
| Terminal | SwiftTerm LocalProcessTerminalView running login shell | Public (third-party library) | None [inferred] | None (50 ms deferred UI work) | Low |
| Caffeinate | IOPMAssertion (no display sleep or no idle system sleep) | Public | None | 1 s Combine ticker | Low |
| Per-app volume | CoreAudio process objects, process taps, stacked aggregate device | Public (macOS 14.2+ tap API) | System audio capture (TCC) | 1.5 s / 5 s poll, property listeners | Medium |
| Shortcuts / hotkeys | KeyboardShortcuts package, global NSEvent mouse monitors | Public (package uses Carbon hot keys [inferred]) | None for hot keys [inferred] | None | Low |
| Media-key interception | CGEventTap at HID/session level, can swallow keys | Public API, undocumented event payload | Accessibility | Retry with back-off for a bounded time | Medium |
| System HUD suppression (OSD) | Pauses, resumes and restarts the system OSD helper process | Private/undocumented | None beyond Accessibility | Sleep/wake observers; no timer | High |
| Brightness (display) | Private CoreBrightness class via runtime lookup | Private | None [inferred] | None | High |
| Keyboard backlight | Private IORegistry property on HID driver + CoreBrightness client | Private | None [inferred] | None | High |
| Extension RPC server | A local WebSocket server on a fixed loopback port, plus an XPC service | Public APIs, custom protocol | Entitlement for mach service | Not timer-driven | Low API risk; security high |
| App Intents / Shortcuts / URL scheme | None found | n/a | n/a | n/a | n/a |

---

## 1. File tray

**What it does.** A tray in the notch that holds dropped files, links, text and raw data. Items can be dragged back out, previewed, shared, opened, revealed in Finder, or removed. Files can also be pushed in from the command line (see the README quick-start section) [verified README].

**Frameworks and APIs.**
- AppKit drag and drop: drag registration on a custom view and SwiftUI `onDrop` [verified `DynamicIsland/components/Shelf/DragDropView.swift` (registerForDraggedTypes), `DynamicIsland/components/Shelf/Views/ShelfView.swift` (onDrop)]. Public.
- Item loading from `NSItemProvider` (file URL, URL, text, data) [verified `DynamicIsland/components/Shelf/Services/ShelfDropService.swift`]. Public.
- Bookmarks via `bookmarkData` / `URL(resolvingBookmarkData:)`, plain not security-scoped [verified `DynamicIsland/components/Shelf/Models/Bookmark.swift:35-115`]. Public.
- Temp storage in the temporary directory, one UUID folder per item, deleted only if the path is under the temp directory [verified `DynamicIsland/components/Shelf/Services/TemporaryFileStorageService.swift`]. Public.
- Persistence: JSON file in Application Support under a subfolder of the app's own Application Support directory, atomic write, per-item tolerant decode [verified `DynamicIsland/components/Shelf/Services/ShelfPersistenceService.swift:28-96`]. Public.
- Drag out: `NSDraggingSession` with `NSDraggingItem` and pasteboard writers, with an operation mask and an end callback [verified `DynamicIsland/components/Shelf/Views/ShelfItemView.swift:453-545`]. Public.
- Preview: `QLPreviewPanel` [verified `DynamicIsland/components/Shelf/Services/QuickLookService.swift`]. Thumbnails: `QLThumbnailGenerator` [verified `DynamicIsland/components/Shelf/Services/ThumbnailService.swift`]. Public.
- Open / reveal: `NSWorkspace` open and activate-file-viewer calls [verified `DynamicIsland/components/Shelf/Services/ShelfActionService.swift`]. Public.

**Storage model (the important part).**
- Dropped files are referenced by a bookmark and a path, not copied, by default [verified `ShelfDropService.swift:93-103`, `ShelfItem.swift`].
- A second path copies the file into the tray's own storage [verified `DynamicIsland/components/Shelf/DropItem.swift:39-47`, `Ext+FileProvider.swift:23-34`]. So both reference and copy models exist in the code.
- Dropped raw data is written to a temp file first, then referenced [verified `ShelfDropService.swift:77-80`].

**Sandboxing and security-scoped access.**
- The app is not sandboxed: sandboxing is switched off in the project settings [verified `DynamicIsland.xcodeproj/project.pbxproj` lines 791, 866; entitlements file has no app-sandbox key, `DynamicIsland/DynamicIsland.entitlements`].
- Atoll uses plain bookmarks, not security-scoped ones [verified `DynamicIsland/components/Shelf/Models/Bookmark.swift`]. Whether security-scoped bookmarks work in an unsandboxed app needs checking against Apple's documentation and on device before DropNotch relies on either kind [inferred].
- Security-scoped access calls are still used in quick look and share code paths [verified `DynamicIsland/extensions/URL+SecurityScoped.swift`, `QuickShareService.swift`]. These are no-ops or harmless for a non-sandboxed app [inferred].
- macOS privacy (TCC) prompts for Desktop, Documents and Downloads still apply to unsandboxed apps [inferred, general platform knowledge]. Do not assume the tray can read any folder silently.

**Entry points.**
- Files arrive through the app's open-URLs and open-file delegate methods [verified `DynamicIsland/DynamicIslandApp.swift:168-181`], which is how the README's CLI example works [verified README "Quick Start"].

**Permissions/entitlements.** None special. No Full Disk Access prompt or check was found in the tray files [verified by search of the tray folder, not exhaustive].

**Files.** `DynamicIsland/components/Shelf/` (all subfolders), `DynamicIsland/components/Notch/NotchShelfView.swift`, `DynamicIsland/DynamicIslandApp.swift:168-181`.

**Timers / polling.**
- Marquee autoscroll: 60 Hz timer, created only while the user drags a selection band [verified `DynamicIsland/components/Shelf/Views/ShelfMarqueeSelectionView.swift:255-262`]. Energy note for DropNotch: keep it tied to the drag, as they do.
- Small deferred UI work via `asyncAfter` (0.05 s to 0.5 s) [verified `Ext+FileProvider.swift:65`, `FileShareView.swift:224`].

**Tests.** No tray tests were found in `DynamicIslandTests/` [verified file listing].

**Breakage risk: medium.** Public APIs, but the source records a bookmark-option regression on a newer macOS and the drag-out code depends on AppKit drag session timing. Keep the bookmark path behind a fallback.

---

## 2. AirDrop and share sheet

**What it does.** Sends the tray's files to AirDrop or to any share extension. A row of sharing providers lists AirDrop first. A drop target on the AirDrop view accepts files.

**Frameworks and APIs.**
- `NSSharingService(named:)` with the AirDrop service name, `canPerform(withItems:)`, `perform(withItems:)`, and the sharing service delegate [verified `DynamicIsland/components/Shelf/AirDrop.swift:24-50`]. Public.
- `NSSharingService.sharingServices(forItems:)` enumerated off the main thread, cached, AirDrop moved to the top, text-support probe [verified `DynamicIsland/components/Shelf/Services/QuickShareService.swift:64-127`]. Public.
- Fallback `NSSharingServicePicker` shown for items that cannot be performed directly [verified `QuickShareService.swift:248-254`]. Public.
- **Service harvesting trick.** A helper type builds an `NSSharingServicePicker`, shows it on a zero-size view, reads the services from the delegate callback, and resumes after a 2 s timeout [verified `DynamicIsland/components/Shelf/Services/ShareServiceFinder.swift:23-58`]. Public API used in an unintended way. Medium risk: depends on the picker calling its delegate while hidden [inferred].
- Errors are shown with `NSAlert` [verified `DynamicIsland/components/Shelf/Ext+NSAlert.swift`]. Public.

**Permissions.** No permission for sending via AirDrop beyond the user's own action [inferred]. The receiving side is controlled by macOS, not by Atoll.

**Files.** `DynamicIsland/components/Shelf/AirDrop.swift`, `AirDropView.swift`, `Services/QuickShareService.swift`, `Services/ShareServiceFinder.swift`, `Views/FileShareView.swift`, `ViewModels/ShelfItemViewModel.swift`.

**Timers.** 2 s one-shot timeout in the harvesting path [verified `ShareServiceFinder.swift:55`]. 0.5 s deferred UI work in `AirDropView.swift:154, 172` [verified].

**Breakage risk: low for `sendViaAirDrop` and sharing-service enumeration (public); medium for the picker-harvesting trick.** Recommendation for DropNotch: use the public AirDrop sharing service directly and skip the picker trick.

### 2a. LocalSend peer transfer (same folder, not AirDrop)

**What it does.** Discovers nearby devices running the LocalSend open protocol and sends files to them, with progress and a live activity.

**Frameworks and APIs.**
- Network.framework: `NWConnectionGroup` with a UDP multicast group, `NWListener` on a TCP port, `NWParameters` [verified `DynamicIsland/components/Shelf/Services/LocalSendService.swift:11-15, 61-63, 94-104, 627-629`]. Public.
- `URLSession` with a delegate for uploads and progress [verified `LocalSendService.swift:998, 1053-1074`]. Public.
- Subnet probing: HTTP(S) requests to local IP addresses with short timeouts and limited concurrency [verified `LocalSendService.swift:186-301`]. Public API, noisy traffic.
- Ephemeral URL session with short probe timeouts [verified `LocalSendService.swift:362-367`].

**Security concern (do not copy).** The TLS challenge handler accepts any server trust it is offered [verified `LocalSendService.swift:1058-1065`]. Any peer on the LAN can impersonate a device, and the upload is then sent to it. For DropNotch, if a peer protocol is ever built, pin or verify the peer's certificate fingerprint and ask the user before sending.

**Permissions.** Local network access. No Local Network usage-description key was found in `DynamicIsland/Info.plist` [verified by search]. macOS shows a Local Network prompt for LAN connections [inferred, general platform knowledge], so the app may get it without a declared reason. Check before shipping.

**Timers.**
- Announce every 8 s while discovery is on [verified `LocalSendService.swift:118-127`].
- Cleanup of stale peers every 15 s [verified `LocalSendService.swift:118-127`].
- Auto-dismiss of completed and failed states after 3 s and 4 s [verified `LocalSendService.swift:573-590`].
- Discovery runs as a long-lived loop, which is the energy cost to weigh [inferred].

**Breakage risk: low technically (public Network.framework and URLSession); security risk high.** The protocol itself is third-party [inferred].

**Files.** `DynamicIsland/components/Shelf/Services/LocalSendService.swift` (1116 lines), `Views/LocalSendLiveActivity.swift`, `Views/FileShareView.swift`.

---

## 3. Clipboard history

**What it does.** Keeps a short list of recent copies (text, RTF/HTML converted to RTF, images, file URLs). Items can be pinned, re-copied to the pasteboard, dragged out, and the history can be kept across restarts or session-only.

**How it watches the pasteboard.**
- Polls the general pasteboard's `changeCount` every 0.5 s using a repeating `Timer` on the main run loop [verified `DynamicIsland/managers/ClipboardManager.swift:376-386`]. Public API, documented change counter.
- Only the change count is read on each tick. The content is read only after the count changes [verified `ClipboardManager.swift:561-572`].
- Monitoring is started from app startup code, guarded by a check that it is not already running [verified `DynamicIsland/DynamicIslandApp.swift:1359-1360`].
- De-duplication: a new item is skipped if its content matches an item already in history [verified `ClipboardManager.swift:567-572`, content comparison helper at `:145`].

**What it reads.** On change it checks file URLs (filtered: must exist, and files in system temporary locations are dropped), then PNG/TIFF/JPEG image data, then plain string, then RTF/HTML [verified `ClipboardManager.swift:575-640`, HTML-to-RTF note at `:803-805`]. Reads from other apps' pasteboards may trigger a macOS privacy alert on newer releases [inferred, general platform knowledge; confirm against Apple's NSPasteboard documentation before relying on it].

**Concealed and transient types.** **None handled.** Searches of `DynamicIsland/` and `DynamicIslandTests/` for the community pasteboard markers for concealed and transient content, and for "concealed"/"transient" as pasteboard concepts, found nothing relevant [verified by search; the only "transient" hits are unrelated UI animation names]. So Atoll would record password-manager copies. DropNotch must skip these types, which is the privacy rule already in our CLAUDE.md.

**Persistence and storage.**
- A short default history with persistence **on** by default [verified `DynamicIsland/models/Constants.swift:1345, 1349`]. Persistence is on by default in Atoll; DropNotch's rule is local-only and it should decide its own default deliberately.
- Item metadata is JSON in UserDefaults under two keys, one for history and one for pinned items [verified `ClipboardManager.swift:769-793`].
- Image bytes go to PNG files in a subfolder of Documents [verified `ClipboardManager.swift:243-253`, `:512-520`]. Files are removed when items leave history [verified `:536-545`, `:688-706`].
- When persistence is off, image bytes are kept in memory only and pruned as items leave [verified `ClipboardManager.swift:34-49` comment and code].
- Rich text over a size limit is dropped from the item [verified `ClipboardManager.swift`, the clipboard item's rich-text initialiser]. DropNotch chooses its own limit.
- Turning persistence off erases unpinned data on disk and in defaults; launch purges when off [verified `ClipboardManager.swift:243-337`].

**Paste-back and drag-out.**
- Re-copy writes the chosen item to the general pasteboard [verified `ClipboardManager.swift:408-423`]. The user pastes themselves. No synthetic keystroke was found in the clipboard files [verified by search].
- Drag-out uses SwiftUI `onDrag`, which has no end callback. The notch is held open by an 8 s safety timer [verified `ClipboardManager.swift:385-404`; Atoll chose a SwiftUI drag source over an AppKit one, see `DynamicIsland/components/Clipboard/ClipboardDragging.swift`].

**Panel.** A borderless, non-activating `NSPanel` at floating level, which can become key [verified `DynamicIsland/components/Clipboard/ClipboardPanel.swift:32-67`]. The app is activated with `NSApp.activate` when the panel opens [verified `DynamicIsland/managers/ClipboardPanelManager.swift:42`]. It has a default clipboard hotkey [verified `DynamicIsland/Shortcuts/ShortcutConstants.swift:27`]; DropNotch picks its own.

**Logging.** Two `print` calls on error paths, with error text only and no content [verified `ClipboardManager.swift:104, 520`]. They use `print`, not `os.Logger` [verified]; DropNotch should use `os.Logger` with privacy-marked content.

**Tests.** `DynamicIslandTests/ClipboardHistoryPersistenceTests.swift`: a dozen tests on the privacy promise: nothing written when off, purge on disable and at launch, pinned images kept, image bytes not written to disk when off, tests run against a temporary directory override [verified file, test names at lines 105-331]. **No tests** for change-count polling, de-duplication, concealed/transient skipping, or the size limit [verified by test list].

**Permissions.** None declared [verified entitlements, Info.plist]. Pasteboard read prompts on newer macOS [inferred, see above].

**Files.** `DynamicIsland/managers/ClipboardManager.swift` (825 lines), `ClipboardPanelManager.swift`, `ClipboardWindowManager.swift`, `DynamicIsland/components/Clipboard/*`, `DynamicIsland/components/Notch/NotchClipboardView.swift`, `ClipboardHistoryPopover.swift`, `DynamicIsland/helpers/Clipboard+Content.swift`.

**Breakage risk: low for polling (documented API); medium for reads of other apps' content (privacy prompts that may change per macOS release) [inferred].**

---

## 4. Notes

**What it does.** Quick notes in the notch: a list of notes with title and body, optional image attachments, autosave, and an optional two-way sync with the Apple Notes app.

**Storage.**
- Note list is a Defaults-backed array of note items [verified `DynamicIsland/components/Notch/NotchNotesView.swift:27`]. Defaults-backed storage means note text is in the app's preferences plist [inferred from Defaults usage].
- Note images are written as files in a per-app notes image folder [verified `NotchNotesView.swift` image write near the top of the save path].
- Autosave debounced by 1.5 s [verified `NotchNotesView.swift:279-284`].

**Apple Notes sync.**
- Uses AppleScript (`NSAppleScript`) to fetch, create, update and delete notes in the Notes app [verified `DynamicIsland/managers/AppleNotesSyncManager.swift:75-130, 209-340`]. Public scripting, but Automation (Apple Events) permission is required [verified: the error type directs the user to Automation settings, `AppleNotesSyncManager.swift:26-33`].
- Merge rule: notes are linked by a remote id. Duplicate remote ids are deduplicated before building the lookup, because a duplicate would crash a dictionary builder [verified `AppleNotesSyncManager.swift:126-156`; the comment there records this].
- Entitlements list apple-events exceptions for Notes and Music [verified `DynamicIsland/DynamicIsland.entitlements`]. These temporary-exception keys only matter for a sandboxed app, so they are likely unused here [inferred].
- Sync is opt-in via a Defaults toggle and runs in a `Task` [verified `AppleNotesSyncManager.swift:65-76`]. Whether the NSAppleScript calls block the main thread was not traced [inferred].

**Permissions.** Automation for Notes. No other permission found.

**Timers.** 1.5 s autosave debounce only [verified].

**Tests.** None in `DynamicIslandTests/` for notes [verified file listing].

**Breakage risk: medium.** AppleScript dictionaries for Notes can change between macOS releases, and scripting access is a user-consent gate. Keep sync out of the MVP.

**Files.** `DynamicIsland/components/Notch/NotchNotesView.swift`, `DynamicIsland/managers/AppleNotesSyncManager.swift`.

---

## 5. Timers

### 5a. Atoll's own countdown timer

**What it does.** A countdown timer shown in the notch with presets, pause/resume, a live activity and a completion beep.

- Countdown uses a 1 s repeating `Timer` [verified `DynamicIsland/managers/TimerManager.swift:191-200`, also `:296`].
- Completion uses `NSSound.beep` [verified `TimerManager.swift:509, 519`]. No notification framework was found in the timer code [verified by search for UNUserNotificationCenter across `DynamicIsland/`: no matches].
- A 3 s deferred work item is scheduled after completion [verified `TimerManager.swift:471`]; what it does was not traced.

**Frameworks.** Foundation `Timer`, AppKit `NSSound`. Public.
**Permissions.** None.
**Breakage risk: low.**
**Files.** `DynamicIsland/managers/TimerManager.swift`, `DynamicIsland/components/Timer/*`, `DynamicIsland/models/TimerPreset.swift`.
**Tests.** `tests/TimerLifecycleRegression.swift` is a lifecycle regression file [verified file exists; its test count was not read].

### 5b. Mirror of the system Clock app's timer

**What it does.** Shows and controls a countdown started in the built-in Clock app, by reading the Clock app's state and pressing its controls.

**Mechanisms (all undocumented or private).**
- Starts a child process running the system log tool and streams a logging subsystem belonging to the Clock app's timer daemon, with a predicate and JSON output [verified `DynamicIsland/managers/SystemTimerBridge.swift:279-289`]. **Private/undocumented** log subsystem name.
- Reads the Clock app's private preferences domain (through CFPreferences and a file in the user's Library) for the timer list [verified `SystemTimerBridge.swift:74-76, 965-976`]. **Private.**
- Watches that preferences file with a file-system dispatch source [verified `SystemTimerBridge.swift:436-453`]. Public API, private file.
- When logs are unavailable, falls back to Accessibility: finds the Clock app's menu-bar extra in the system-wide AX tree and reads its title and value text [verified `SystemTimerBridge.swift:1002-1090`]. Public AX API, scraping a private UI.
- Controls the timer by performing an AX press on the Clock app's buttons [verified `SystemTimerBridge.swift:1174-1242`]. Public AX API, private UI.

**Timers.** Ticker of 1 s with 150 ms leeway, only when the Accessibility fallback is active [verified `SystemTimerBridge.swift:260-269`]. Main-thread updates throttled to a low rate [verified `SystemTimerBridge.swift:105, 541-552`].

**Permissions.** Accessibility (for the AX fallback and control) [verified `SystemTimerBridge.swift:361, 375`].

**Breakage risk: high.** Scrapes UI text, depends on a log subsystem name and a preferences layout. Any Clock redesign or logging change silently breaks it. Do not copy. If DropNotch wants this, make it an opt-in feature behind a protocol with a no-op fallback, as CLAUDE.md requires for private APIs.

**Files.** `DynamicIsland/managers/SystemTimerBridge.swift` (1288 lines), `DynamicIsland/managers/TimerManager.swift` (`:164-410` for external timer adoption).

---

## 6. Terminal

**What it does.** A terminal tab in the notch that runs the user's login shell.

**Frameworks and APIs.**
- SwiftTerm package, pinned in the project's resolved packages at version 1.13.0 [verified `reference/atoll/DynamicIsland.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, entry "swiftterm"; also `DynamicIsland.xcodeproj/project.pbxproj:1016-1018`].
- The view is SwiftTerm's local-process terminal view. The shell is launched as a login shell with a cleaned environment [verified `DynamicIsland/managers/TerminalManager.swift:288-298, 627-633`].
- Under the hood the library spawns a pseudo-terminal child process [inferred from library behaviour].
- README credits SwiftTerm and says the tab was adapted from it [verified `reference/atoll/ReadMe.md` acknowledgements]. DropNotch should use the library directly, not copy Atoll's wrapper.

**Permissions.** None declared. The child shell is a child of the app, so macOS privacy attribution (TCC) goes to Atoll for any protected folder the shell touches [inferred].

**Timers.** None repeating. Two 50 ms deferred UI calls [verified `TerminalManager.swift:583, 598`].

**Other notes.** The file contains translucency and layer workarounds for the terminal view [verified `TerminalManager.swift:358-432`]. Not needed for MVP.

**Licence.** SwiftTerm licence not checked in the reference; I believe it is MIT [inferred, must be verified in docs/DECISIONS.md before adding].

**Breakage risk: low** (public API of a maintained library).
**Files.** `DynamicIsland/managers/TerminalManager.swift` (670 lines), `DynamicIsland/components/Notch/NotchTerminalView.swift`.

---

## 7. Caffeinate (keep awake)

**What it does.** Keeps the Mac awake for a chosen duration or until toggled off. Option to keep the display on or only prevent idle system sleep.

**Frameworks and APIs.**
- IOKit power management assertions, created with a "no display sleep" type or a "prevent user idle system sleep" type, released on stop or when the duration ends [verified `DynamicIsland/managers/CaffeinateManager.swift:78-115`]. Public API (IOKit power management) [inferred from the API names and general platform knowledge].
- Remaining-time label updated by a 1 s Combine timer on the main run loop [verified `CaffeinateManager.swift:141`].
- Keyboard toggle wired through the shortcut library [verified `DynamicIslandApp.swift:1421-1423`, default in `ShortcutConstants.swift:36`].
- Preference observer and enable/disable flow [verified `CaffeinateManager.swift:57`, `DynamicIslandApp.swift:879`].

**Permissions.** None.
**Timers.** 1 s ticker only while a timed session runs [verified line 141; stop behaviour at the deactivate path].
**Tests.** `DynamicIslandTests/CaffeinateManagerTests.swift` exists [verified file listing; not read].
**Breakage risk: low.**
**Files.** `DynamicIsland/managers/CaffeinateManager.swift`, `DynamicIsland/components/Caffeinate/CaffeinatePopover.swift`.

---

## 8. Per-app volume

**What it does.** Per-app volume sliders and mute for apps that are currently playing audio, without changing the system volume.

**Frameworks and APIs (CoreAudio, public).**
- Lists process objects and translates a process ID to its audio process object, reads bundle ID, PID and "is running output" [verified `DynamicIsland/audio/PerAppVolume/AudioProcessQuery.swift:29-175`]. Public CoreAudio property selectors.
- Creates a process tap for one or more processes with mute-when-tapped behaviour, a private stacked aggregate device that wraps the tap and the real output device, and an IO callback that scales samples [verified `DynamicIsland/audio/PerAppVolume/AppVolumeTap.swift:65-141`]. Public APIs introduced for macOS 14.2 [inferred from the API names and general platform knowledge; confirm on Apple's Core Audio documentation].
- Gain is written from the main thread and read on the real-time thread, with a per-buffer ramp to avoid clicks [verified `AppVolumeTap.swift:36-50` comments].
- Teardown runs in reverse order of creation, as Core Audio requires [verified `AppVolumeTap.swift:200-217`].

**Manager.** Keeps one tap per app that has a non-default level, reconciles when the process list or the default output device changes (property listeners), and persists mute state [verified `DynamicIsland/managers/PerAppVolumeManager.swift:49-125, 170-200`]. Mute state in Defaults [verified `PerAppVolumeManager.swift:112-115`].

**Timers.**
- Refresh poll every 1.5 s while the list is visible, every 5 s while taps exist, none otherwise [verified `PerAppVolumeManager.swift:184-194`].

**Permissions.** System audio capture (the TCC "audio capture" category). Usage text is set in Info.plist [verified `DynamicIsland/Info.plist` key for audio capture]. Requested on use [inferred].

**Availability.** The tap code is in `audio/` and the manager does not show an availability check [verified by searching those folders for availability annotations: none]. Deployment targets differ between configurations [verified `DynamicIsland.xcodeproj/project.pbxproj` lines 574, 595, 620, 647]. DropNotch targets 14.0 and must gate this feature on 14.2+ [inferred from the API version].

**Tests.** `DynamicIslandTests/PerAppVolumeTests.swift` (with `SystemHUDPlacementTests.swift`: 20 test functions in total) [verified count].

**Breakage risk: medium.** Public APIs, but the behaviour of taps and aggregate devices has shifted between macOS releases and Bluetooth route changes add edge cases. Keep it behind a flag and a version check.

**Files.** `DynamicIsland/audio/PerAppVolume/AudioProcessQuery.swift`, `AppVolumeTap.swift`, `DynamicIsland/managers/PerAppVolumeManager.swift`, `DynamicIsland/components/Audio/PerAppVolumePopover.swift`.

---

## 9. Keyboard shortcuts and hotkeys

**What it does.** Global hotkeys for the app's main features and display brightness, all remappable.

**Frameworks and APIs.**
- The KeyboardShortcuts Swift package, pinned in the resolved packages [verified `DynamicIsland.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, identity "keyboardshortcuts"]. Named shortcuts with defaults and handlers [verified `DynamicIsland/Shortcuts/ShortcutConstants.swift:26-36`, handlers at `DynamicIslandApp.swift:1421`].
- A SwiftUI view extension helper for shortcut display [verified `DynamicIsland/extensions/KeyboardShortcutsHelper.swift`].
- Hot-key registration in the package uses Carbon hot-key APIs under the hood [inferred from the package's known design]. Carbon hot keys are old but still work and do not need Accessibility [inferred].
- Global mouse monitors (`NSEvent` global and local monitors for mouse-down) for click-outside handling and sticky terminal behaviour [verified `DynamicIsland/ContentView.swift:2180-2225`]. Global mouse-down monitors do not need Input Monitoring [inferred]; global key monitors do.

**Permissions.** None for Carbon hot keys [inferred]. No Input Monitoring prompt in the code I read [verified by search for input-monitoring APIs: none beyond the media-key tap].

**Timers.** None.
**Breakage risk: low.** Carbon hot-key APIs are old but stable [inferred].
**Files.** `DynamicIsland/Shortcuts/ShortcutConstants.swift`, `DynamicIsland/extensions/KeyboardShortcutsHelper.swift`, `DynamicIslandApp.swift:1421-1481`.

**DropNotch note.** Adding this package needs Shash's approval and a licence check first (CLAUDE.md). Its licence was not checked here [inferred: MIT].

---

## 10. Media-key interception and system HUD replacement

This covers the volume, brightness and keyboard backlight key replacement. The actual volume and music controls belong to the media analyst.

### 10a. Media-key tap

**What it does.** Intercepts volume, mute, brightness and keyboard-illumination keys so Atoll can show its own HUD, and in some cases consumes the key.

**Mechanism.**
- Creates a `CGEvent` tap with default (active, can-modify) options, placed at the head of the HID event stream, and listening for system-defined events [verified `DynamicIsland/managers/MediaKeyInterceptor.swift:186-229`]. Public API.
- Decodes the system-defined payload into a key type and key state [verified `MediaKeyInterceptor.swift:31-35` for the key-type constants, `:147` for event type]. The payload layout is **undocumented** but has been stable for years [inferred].
- For volume and brightness keys it returns nil (consumes the event) when the matching option is on, and passes it through otherwise [verified `MediaKeyInterceptor.swift:360-385`].
- Tap disabled by timeout or user input is re-enabled [verified `MediaKeyInterceptor.swift:327-337`].
- Requires Accessibility. Prompts with the trust-check options dictionary [verified `MediaKeyInterceptor.swift:466-469`, `AXIsProcessTrusted` gate at `:285`].
- Installing the tap after the user grants permission needs a retry, because granting Accessibility does not relaunch the app [verified `MediaKeyInterceptor.swift:160-164`, `:237-285`].

**Timers and retry policy.** Retries with back-off for a bounded time, then gives up [verified `MediaKeyInterceptor.swift:73-93`, policy tests in `DynamicIslandTests/MediaKeyTapRetryPolicyTests.swift`, file exists, not read]. An Accessibility status poll uses a 0.5 s sleep loop [verified `DynamicIsland/helpers/AccessibilityPermissionStore.swift:62-72`]; the stop condition was not traced.

**Permissions.** Accessibility.
**Breakage risk: medium.** Public tap API, but media-key routing and the system-defined payload have changed across releases [inferred]. Keep it optional, with a fallback to no interception.

**Files.** `DynamicIsland/managers/MediaKeyInterceptor.swift` (473 lines), `DynamicIsland/helpers/AccessibilityPermissionStore.swift`, `DynamicIsland/managers/SystemVolumeManager.swift` (reads volume via AppleScript [verified `:6-23`]).

### 10b. System OSD suppression

**What it does.** Hides the system's own volume and brightness on-screen display, so the notch HUD is the only one shown.

**Mechanism (private, process control).**
- Suspends the system on-screen-display helper process with a stop signal and records its PID, because the helper gets killed when idle and relaunched on the next key press [verified `DynamicIsland/managers/SystemOSDManager.swift:24-60, 108-127`].
- Re-enable: the helper is stopped and restarted through the system's service manager, with a fallback. The exact commands are not recorded here [verified `SystemOSDManager.swift:103-170`].
- Termination path sends a continue signal so the helper is not left frozen [verified `SystemOSDManager.swift:173-210`]. Sleep and wake handlers exist, and the wake path re-suspends a freshly spawned helper [verified `SystemOSDManager.swift:69-89`, comment at `:82`].
- Triggered from the system-change observer on several events [verified `DynamicIsland/managers/SystemChangesObserver.swift:193, 213, 226`].

**Permissions.** None beyond what the process can do as the logged-in user (no sandbox, no entitlement) [inferred].
**Breakage risk: high.** Relies on a private helper's name, a launchd label and LaunchAgent path, and on it being restartable. A macOS update can change any of these, and a crash can leave the native HUD stopped unless the terminate path runs. Do not copy. DropNotch's CLAUDE.md requires a protocol and fallback; if this feature exists at all, the fallback must always restore the native HUD.

### 10c. Brightness (display)

**Mechanism (private).** Loads the private CoreBrightness framework by path, resolves a display-brightness client class by trying a list of candidate class names, and calls its getter and setter through unsafe method pointers cast to C function types [verified `DynamicIsland/helpers/CoreBrightnessDisplayClient.swift:19-103`]. The class names are private.
**Fallback.** Logs a warning and degrades when the framework or class is missing [verified `CoreBrightnessDisplayClient.swift:58-72`].
**Permissions.** None [inferred].
**Breakage risk: high.** Private framework and private class names; unsafe casting of method pointers.

### 10d. Keyboard backlight

**Mechanism (private).** Reads and writes a property on the HID keyboard driver's registry entry, scaled to a private maximum, and also uses a CoreBrightness keyboard client [verified `DynamicIsland/managers/KeyboardBrightnessSensor.swift:24-28, 86-150, 153-175`]. Controlled from `DynamicIsland/managers/SystemKeyboardBacklightController.swift` (main-thread callbacks, notifications).
**Permissions.** None [inferred].
**Breakage risk: high.** Undocumented registry property and private client; Apple-silicon specific in practice [inferred].

### 10e. Third-party DDC brightness helper

**What it does.** When a third-party external-display helper app is running, Atoll hands brightness over to it and only uses volume from the helper if that option is set [verified `DynamicIsland/managers/SystemHUDManager.swift:258-297`]. Which helper apps are supported was not traced [inferred: DDC helpers are third-party external-display utilities].

### 10f. Dead code: a key observer subclass

`DynamicIsland/managers/SystemKeyObserver.swift` is an `NSApplication` subclass that overrides event sending to catch system-defined keys and post notifications. **No references to it were found** outside its own file, and the app's Info.plist sets no principal class [verified by search]. Do not copy it; it is not wired up.

**Tests.** `DynamicIslandTests/SystemHUDPlacementTests.swift` [verified file; counted with per-app volume tests above].

**Files.** `DynamicIsland/managers/SystemHUDManager.swift`, `SystemOSDManager.swift`, `MediaKeyInterceptor.swift`, `SystemKeyboardBacklightController.swift`, `KeyboardBrightnessSensor.swift`, `CoreBrightnessDisplayClient.swift`, `helpers/SystemHUDDebugger.swift`, `components/OSD/*`.

---

## 11. Extension RPC server and XPC service

**What it does.** Lets third-party apps (extensions) push live activities, lock screen widgets and notch experiences into Atoll, using JSON-RPC 2.0 over WebSocket and an XPC mach service.

**Frameworks and APIs (public).**
- Network.framework: two `NWListener`s bound to the IPv4 and IPv6 loopback addresses on a fixed port, plus WebSocket framing [verified `DynamicIsland/services/Extensions/ExtensionRPCServer.swift:19-110`]. Public.
- Every accepted connection's peer address is checked for loopback, including IPv4-mapped IPv6 [verified `ExtensionRPCServer.swift:300-335`]. Public APIs for address checks.
- XPC: an `NSXPCListener` on a mach service name with the matching entitlement [verified `DynamicIsland/services/Extensions/ExtensionXPCServiceHost.swift:24-60`, `DynamicIsland/DynamicIsland.entitlements` mach-services key]. Public.
- The client's identity is resolved from the running application that owns the connection's process ID [verified `ExtensionXPCServiceHost.swift:125-132`]. Public API, but identity from a PID lookup is a weak check [inferred].
- Lifecycle notifications are posted as distributed notifications with an app-specific name prefix [verified `DynamicIsland/services/Extensions/AtollDistributedNotifications.swift:1-20`]. Public.

**Authorisation (security-relevant).**
- RPC: a client is **authorised automatically** when it requests authorisation with a bundle identifier it declares itself. The source approves such clients without a prompt [verified `DynamicIsland/services/Extensions/ExtensionRPCService.swift:139-158`]. There is no prompt in this path.
- XPC: a pending client is authorised on request and the host is told [verified `DynamicIsland/services/Extensions/ExtensionXPCService.swift:45-62`]. A settings screen can authorise and deny entries [verified `DynamicIsland/components/Settings/ExtensionsSettings.swift:467, 488`]. I did not trace whether the settings screen gates first use or only revocation [inferred unknown].
- **No Origin check** in the RPC files [verified by search for origin and host-header handling in `ExtensionRPCServer.swift` and `ExtensionRPCService.swift`: none]. Browsers allow WebSocket connections to localhost [inferred, general platform knowledge], so a web page the user visits may be able to reach the RPC port and self-authorise. The loopback check does not stop that, because the browser's connection is from loopback.

**Tests.** `DynamicIslandTests/ExtensionRPCServerTests.swift`: nine tests on loopback acceptance and refusal, both IPv4 and IPv6 bindings, IPv4-mapped peers, a public address and a lookalike hostname [verified test names at lines 35-103].

**Permissions.** Mach-service entitlement [verified]. No user-facing permission.

**Breakage risk: low for the API (public Network.framework and XPC); high for security.** Recommendation for DropNotch: do not build a localhost RPC server for the MVP. If an extension channel is ever built, use XPC with code-signing requirement checks, a user consent prompt on first use, and no unauthenticated loopback socket.

**Files.** `DynamicIsland/services/Extensions/*` (RPC server, RPC service, RPC messages, XPC host, XPC service), `DynamicIsland/managers/Extensions/*` (the parts that handle permission grants, event forwarding, input validation and lock-screen widgets), `DynamicIsland/components/Settings/ExtensionsSettings.swift`.

---

## 12. Shortcuts, App Intents and URL entry points

- **App Intents / Shortcuts app:** no `AppIntents`, shortcut-provider, or legacy intents usage found anywhere in the source [verified by search of `reference/atoll/DynamicIsland`]. Not a feature of this version.
- **URL scheme:** no URL-type entries in Info.plist [verified by search of `DynamicIsland/Info.plist`]. Not a feature.
- **Command line:** files opened from the command line (see the README quick-start section) reach the tray via the app's open-URLs handler [verified README; `DynamicIslandApp.swift:168-181`].
- **AppleScript:** used internally to read volume and to talk to Notes [verified `SystemVolumeManager.swift`, `AppleNotesSyncManager.swift`]. The app does not expose a scripting dictionary [inferred; none found].

---

## 13. Private and undocumented dependency register

| # | Dependency | Where | Type | Likelihood of breaking on a macOS update | Why |
|---|---|---|---|---|---|
| 1 | Clock app log subsystem, preferences domain, menu-bar AX scraping and AX press | `managers/SystemTimerBridge.swift` | Private, UI scraping | High | Any Clock change silently breaks it |
| 2 | System OSD helper process control (pause, resume and restart through the system service manager) | `managers/SystemOSDManager.swift` | Private process and launchd | High | Helper name, launchd label and restart behaviour can change; a crash can leave native HUD stopped |
| 3 | CoreBrightness display client via runtime class lookup and unsafe method casts | `helpers/CoreBrightnessDisplayClient.swift` | Private framework | High | Private class names and selector signatures |
| 4 | Keyboard backlight IORegistry property plus CoreBrightness keyboard client | `managers/KeyboardBrightnessSensor.swift` | Private registry and framework | High | Undocumented property and client |
| 5 | System-defined media key payload decoding and legacy key-type constants | `managers/MediaKeyInterceptor.swift:31-35, 147` | Undocumented payload, public tap | Medium | Key routing changes between releases |
| 6 | Picker harvesting for sharing services | `components/Shelf/Services/ShareServiceFinder.swift` | Public API used unintendedly | Medium | Relies on delegate timing from a hidden picker |
| 7 | Notes AppleScript dictionary | `managers/AppleNotesSyncManager.swift` | Public scripting, app-specific dictionary | Medium | Notes scripting can change; Automation consent |
| 8 | CoreAudio process taps and stacked aggregate devices | `audio/PerAppVolume/AppVolumeTap.swift` | Public API, macOS 14.2+ | Medium | Behaviour shifts; route changes |
| 9 | Pasteboard reads of other apps | `managers/ClipboardManager.swift` | Public API, privacy-gated | Medium | Privacy prompts may change per release [inferred] |
| 10 | Localhost WebSocket RPC with automatic authorisation | `services/Extensions/ExtensionRPCServer.swift`, `ExtensionRPCService.swift` | Public API, insecure design | Low API risk; high security risk | Not an OS-compatibility issue |
| 11 | Unsafe public-API use for tray bookmarks in an unsandboxed app | `components/Shelf/Models/Bookmark.swift` | Public API, documented regression | Medium | Source notes a macOS 26 regression with the security-scoped option |

Not checked: the reference's other private dependencies (SkyLight, MediaRemote adapter, private CoreGraphics spaces) belong to the other analysts.

---

## 14. Gaps and what I did not check

- Did not read the full UI code of the tray view models (the tray item view model file is about 1,250 lines), clipboard views, or the full terminal and per-app volume UI. Findings are from the services and managers I did read, plus targeted searches.
- Did not run the tests or build the project. Test names were read, test bodies were not.
- Did not trace whether the extension settings screen gates first-use authorisation, only that the code exposes approve and deny actions.
- Did not check git history or the changelog for regressions beyond what the source comments state.
- Licences of SwiftTerm and KeyboardShortcuts were not read from the reference (both marked inferred). Must be confirmed before adding either (CLAUDE.md, dependency-manager).
- Pasteboard privacy prompts and the Local Network prompt behaviour are inferred from general platform knowledge. Confirm against Apple's documentation before relying on them.
- Whether the AppleScript calls for Notes or volume run on the main thread was not traced.
- The Clipboard "persistence on by default" choice is Atoll's. DropNotch should decide its own default under its privacy rule.

---

## 15. Five-line summary for DropNotch

1. **Clipboard:** Atoll polls the change count every 0.5 s (public, cheap), but it never skips concealed or transient pasteboard types and stores text in UserDefaults with persistence on by default. DropNotch must skip those types, keep history local, and never log content; its persistence default should be set on purpose.
2. **File tray and AirDrop:** the MVP can rely on public APIs only: drag and drop, bookmarks, temp copies, JSON persistence, `NSSharingService` for AirDrop. Skip Atoll's picker-harvesting trick and its unsandboxed plain-bookmark workaround; if DropNotch is sandboxed, use security-scoped bookmarks from the start.
3. **Do not copy the risky parts:** the localhost RPC server (auto-authorises self-declared clients, no Origin check), the LocalSend TLS delegate (trusts any server), the Clock-app scraping, and the system OSD helper process control are all high risk or insecure. Keep any HUD replacement optional, behind a protocol, and always able to restore the native HUD.
4. **Per-app volume and media keys are feasible but fragile:** CoreAudio taps (macOS 14.2+) and an Accessibility-gated CGEvent tap are public APIs with medium breakage risk. Gate them on version and permission, use the retry-then-back-off pattern for the tap, and request Accessibility or audio capture only when the user enables the feature.
5. **Energy and tests:** Atoll's timers are sensible (event-driven where possible, a 60 Hz timer only during drag, 1 to 2 s polls only while visible), but its clipboard and notes logic has few tests, and none cover concealed-type skipping. DropNotch should write tests for the privacy rules first, and every new timer needs an interval and justification in docs/ARCHITECTURE.md.
