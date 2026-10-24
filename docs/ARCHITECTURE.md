# Architecture

Status: Phase 1 proposal, 2026-10-24; Phase 2 is building it branch by branch (TASK.md). Once Shash approves this document, it becomes the source of truth for module layout (CLAUDE.md).

Tags: **[V]** verified (seen in this repo, or in a clean-room note under [research/](research/)); **[I]** inferred (Apple-platform knowledge not checked against Apple documentation in Phase 1, or reasoning). Design proposals are not claims and carry no tag. Every [I] item about an Apple API should be checked against Apple's documentation when Phase 2 implements it.

Choices marked **(Dn)** are accepted decisions in [DECISIONS.md](DECISIONS.md).

## 1. Principles

1. Productivity first: a module earns its place by making a frequent action faster.
2. Event-driven by default. Every timer is listed in section 9 with an interval and a reason.
3. Private APIs live behind a protocol in `Services/` with a public fallback, so a macOS update turns off one feature instead of crashing the app (CLAUDE.md).
4. One module = one folder = can be switched off with no side effects (no observers, timers or permission prompts while off).

## 2. Module layout

```
DropNotch/
  App/            DropNotchApp (entry point), AppDelegate, menu-bar item
  Notch/          NotchPanel, NotchGeometry, NotchHoverStateMachine, NotchRootView, ScreenObserver, ModuleRegistry
  Modules/
    NowPlaying/   compact + expanded + settings views, NowPlayingModel
    FileTray/     tray views, TrayStore
    Clipboard/    history views, ClipboardHistoryStore
    Notes/        notes views, NotesStore
  Services/       one protocol + implementations per system dependency:
                  NowPlayingSource (AppleMusic, Spotify; MediaRemote later),
                  PasteboardWatcher, BluetoothBatteryProvider (later), …
  Settings/       Settings window, launch at login (Phase 3), layout editor, per-module settings host
  Support/        Logger categories, file locations, small shared helpers
DropNotchTests/   mirrors the folders above
```

Rules:
- Modules depend on `Services/` protocols, never on each other.
- `Notch/` knows about modules only through the registry (section 3).
- Feature code goes under `DropNotch/Modules/<Feature>/` (CLAUDE.md) [V].
- XcodeGen picks up new files from `sources: [DropNotch]`, so adding a file needs `xcodegen generate` and no project.yml edit [V: project.yml]. Groups follow folders because `createIntermediateGroups: true` is set [V].

## 3. Module protocol and registry

Every feature module implements one protocol. Sketch (Swift, our own design):

```swift
@MainActor
protocol NotchModule: AnyObject, Identifiable where ID == String {
    var id: String { get }                       // stable key used by layout and settings storage
    var title: LocalizedStringResource { get }
    var isEnabled: Bool { get set }              // persisted; false = no observers, no timers, no prompts
    var hasCompactContent: Bool { get }          // e.g. Now Playing only while something is playing

    func compactView(slot: CompactSlot) -> AnyView   // left or right of the notch
    func expandedView() -> AnyView
    func settingsView() -> AnyView

    func start()                                 // called when enabled; begins observing
    func stop()                                  // called when disabled or app quits
}
```

Why it looks like this (notes for a Swift newcomer):
- `@MainActor`: every module drives UI state, so the compiler guarantees it is only touched on the main thread. Background work happens inside services, which hand results back to the main actor.
- `AnyObject`: modules are long-lived reference types the registry owns. A struct would be copied, and `start()`/`stop()` would act on the wrong copy.
- `AnyView` return types: the registry keeps modules of different types in one array. A protocol with an associated `View` type can't sit in a plain array without type erasure, and `AnyView` is the simplest erasure. Apple documents that changing the wrapped view type destroys and rebuilds the hierarchy [V: https://developer.apple.com/documentation/swiftui/anyview]; no diffing cost is documented. Module view types don't change once placed, so this rebuild doesn't recur [I].
- `start()`/`stop()` are separate from `isEnabled` so the registry, not each module, decides when observers run (for example, stop everything when the screen sleeps).

`ModuleRegistry` (in `Notch/`) owns the module instances in a fixed order, calls `start()`/`stop()` when `isEnabled` changes, and gives the layout the enabled modules in user order.

Transient HUDs (timed overlays shown for a few seconds: battery, Bluetooth connect, track change) are a registry feature: a module asks for a timed peek, and the hover state machine shows it. Atoll uses the same idea for its HUDs [V: research/atoll-system-shell.md A2].

## 4. State management

- Models are `@Observable` classes on the main actor (Observation framework, macOS 14+ [V: https://developer.apple.com/documentation/observation/observable]; matches the 14.0 target [V: project.yml]). SwiftUI views update only for the observable properties their body reads [V: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro].
- One model per module (for example `NowPlayingModel`, `TrayStore`) plus one `NotchState` for the hover state machine and layout.
- Services expose `AsyncStream`s or async functions (CLAUDE.md). A module consumes a stream inside a `Task` it starts in `start()` and cancels in `stop()`.
- The hover state machine (`closed → peek → open`) is a plain value type with a pure `transition(event:) -> State` function, so it can be unit-tested without a window. Timers for open delay and exit debounce are owned by `NotchState`, not by views.

## 5. Persistence

| Data | Where | Format | Notes |
|---|---|---|---|
| Settings, module enabled flags, layout | `UserDefaults` via `@AppStorage`/a small settings model | Property list | Small values only. |
| Quick notes | `~/Library/Application Support/DropNotch/Notes/` | One plain-text file per note | Human-readable, easy to back up. Saves are debounced (section 9). |
| File tray items | `…/Application Support/DropNotch/tray.json` | JSON (`Codable`), atomic write | Holds bookmarks or copied-file paths (D6). |
| Clipboard history | Memory by default; optional `…/Application Support/DropNotch/clipboard/` | JSON + image files | Persistence default is D7. Nothing goes to `UserDefaults`, because Atoll's use of it puts clipboard text in a preferences plist [V: research note §3]. |

No Core Data or SwiftData: the data is small, and plain files are easier to inspect and test. Writes go through one `FileLocations` helper so tests can point at a temporary directory (Atoll's clipboard tests use the same pattern [V]).

## 6. Notch panel window

Configuration (all public AppKit; Atoll uses the same flags [V: research/atoll-system-shell.md B1]):
- `NSPanel` subclass, style mask borderless + `nonactivatingPanel`, which Apple defines as a panel that doesn't activate the owning app [V: https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel]. Whether a click still takes focus is a device check.
- Transparent: not opaque, clear background, no shadow, not movable, `hidesOnDeactivate = false`.
- Level: `.statusBar`, one above the main-menu level, so the panel draws over the menu bar (D16; Atoll uses main-menu + 3 [V]).
- Collection behaviour: can join all Spaces, full-screen auxiliary, stationary, ignores window cycling [V: same flags in Atoll].
- Hosts SwiftUI through a small `NSHostingView` subclass with `sizingOptions = []`, so the frames come from `NotchGeometry` only (D16). Once the panel has clickable controls, the subclass overrides `acceptsFirstMouse(for:)` to return true, so one click works without activating the window first. (In AppKit, the first click on an inactive window normally only activates it.) [V: Atoll does the same]
- Can become key only while open and a text field needs input (notes). Closed and peek states never take key focus. In Phase 2 the panel never becomes key (D16).
- App runs as an agent app (`LSUIElement`), set in project.yml [V: https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement].

Closed-state hit testing (**D5, accepted**). A window with `ignoresMouseEvents` set is transparent to mouse events [V: https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents], so hover can't be detected from it. So the closed panel is resized to exactly the notch rectangle (Atoll does the same [V]) and keeps receiving mouse events. A tracking area on it gives hover enter and exit. Everything outside that rectangle is click-through because the window doesn't cover it. On a notched display there is no menu-bar content behind the notch [I: device check; not in Apple docs]. On a non-notch screen the pill blocks clicks only inside its own small rectangle. Rejected: a full-width click-through panel plus a global mouse-moved monitor, which receives a copy of every mouse event sent to other apps [V: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)], so DropNotch would process pointer movement system-wide.

## 7. Notch vs non-notch and external displays

- Notch present when `NSScreen.safeAreaInsets.top > 0` and both auxiliary top areas exist [V: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc]. Notch width = screen width minus `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` widths. Height = top inset [V: Atoll's geometry; APIs are macOS 12+ [I]].
- No notch: draw a pill centred at the top. Height defaults to the menu-bar height (full frame minus visible frame) [V: Atoll offers a mode that uses the menu-bar height].
- Frames are rounded to whole pixels for the screen's backing scale, because the top inset can be fractional (33.5 pt) [V: Atoll comment].
- Display choice for MVP (**D9**): one panel on the built-in display if it has a notch, otherwise on the main display. All-displays mode is v0.2.
- Displays are identified by `CGDirectDisplayID` from the screen's device description, never by localised name. Atoll's use of names can confuse two identical monitors [V: research note B5].
- `NSApplication.didChangeScreenParametersNotification` triggers a reposition, debounced 200 ms as a design choice (Apple doesn't document bursts) [V: https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification]. Space changes need no handling for the public collection behaviour [I: device check]; `NSWorkspace.activeSpaceDidChangeNotification` exists if needed [V: https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification].
- Geometry is computed by a pure value type `NotchGeometry(screenFrame:safeAreaTop:auxLeftWidth:auxRightWidth:menuBarHeight:backingScale:)`, so it is unit-testable without real screens. It outputs `hasNotch`, `closedFrame`, `peekFrame` and `openFrame`, all aligned to whole pixels. `menuBarHeight` sizes the pill; when it is 0 (menu bar auto-hidden), a fixed fallback height is used.
- The display choice is the pure `ScreenObserver.chooseDisplay` (D17).

## 8. Module-specific design notes (MVP)

- **Now Playing (D2):** MVP providers are Apple Music and Spotify. Each listens to its player's distributed notification (event-driven) and sends commands with Apple Events, which needs one Automation prompt per player, on first use [V: Atoll's technique; prompt timing I]. Position between updates is extrapolated from (position, timestamp, rate), never polled [V: Atoll's stream notes describe the same anchor rule]. Sending an Apple Event to a player that isn't running launches it, so commands are sent only when `NSWorkspace` reports the player is running [I: security-auditor note; check in Phase 2]. MediaRemote is a v0.2 optional provider behind the same protocol.
- **File tray:** AppKit drag destination on the open panel; also on the closed panel, so dragging a file onto the notch opens the tray. Items are stored per D6. AirDrop through `NSSharingService(named: .sendViaAirDrop)` [V: public API used by Atoll]. Quick Look thumbnails are generated off the main thread.
- **Clipboard history:** `PasteboardWatcher` service reads `NSPasteboard.general.changeCount` on a timer (section 9). Content is read only when the count changes [V: Atoll does the same]. Items whose types include the concealed or transient markers (`org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, `org.nspasteboard.AutoGeneratedType`) are skipped [I: nspasteboard.org convention; Apple defines no concealed or transient type, https://developer.apple.com/documentation/appkit/nspasteboard/pasteboardtype]. From macOS 15.4 the general pasteboard asks the user on programmatic access [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]; see RISKS.md §2 and the D7 probe. Content is never logged. Re-copy writes to the pasteboard; the user pastes.
- **Quick notes:** text editor in the expanded view, saved to files with a debounce.
- **Layout (D8):** Settings chooses which module fills the compact-left and compact-right slots and the order of tabs in the expanded view.

## 9. Energy budget

Target: zero wake-ups while idle, apart from the clipboard poll. Intervals below are starting values, to be tuned on a real Mac; unlike Atoll's always-on loops, every repeating timer here runs only while its view is visible or its feature is in use. The performance-optimizer agent checks this before each release.

### Event-driven (no timers)

| What | Event source |
|---|---|
| Hover open/close | AppKit tracking area enter/exit on the notch panel |
| Screen changes | `didChangeScreenParametersNotification` (+ 200 ms one-shot debounce) |
| Now playing (Music, Spotify) | The player's distributed notification on track or state change [V] |
| File tray | Drag-and-drop callbacks |
| Notes | Text-change callbacks |
| Settings | `UserDefaults`/Observation changes |
| Screen sleep, lock, wake | `NSWorkspace` screens-did-sleep/wake notifications [V: https://developer.apple.com/documentation/appkit/nsworkspace/screensdidsleepnotification]; they pause the clipboard poll and animations. No screen-lock notification is in Apple's NSWorkspace reference; the documented session notifications cover user switching [V: https://developer.apple.com/documentation/appkit/nsworkspace/sessiondidresignactivenotification], so the MVP pauses on screen sleep only; lock detection is checked in Phase 2 step a |
| v0.2: battery | IOKit power-source run-loop source [V] |
| v0.2: Bluetooth connect | IOBluetooth connect/disconnect registration [V: documented API exists; Atoll doesn't use it] |
| v0.2: calendar | EventKit store-changed notification [V] |

### Timers that genuinely need to exist

| Timer | Interval | Runs when | Why it can't be an event |
|---|---|---|---|
| Clipboard `changeCount` poll | 0.5 s, tolerance 0.25 s (D7) | Clipboard module enabled and screen awake | The `changeCount` page describes only the counter; no change notification is documented [V: https://developer.apple.com/documentation/appkit/nspasteboard/changecount]. Reading one integer per tick is cheap [I: not measured]. Atoll uses 0.5 s [V]. |
| Hover open delay | One-shot 0.3 s | Pointer enters the closed notch | Avoids opening when the pointer just passes through. Atoll's default is 0.3 s [V]. |
| Hover exit debounce | One-shot 0.1 s | Pointer leaves | Avoids flicker at the edge [V: Atoll uses 100 ms]. |
| Peek dismissal | One-shot, 2–3 s | A peek HUD is showing | Timed by definition. |
| Screen-change debounce | One-shot 0.2 s | Display change burst | Coalesces bursts. |
| Notes autosave | One-shot 1 s after last keystroke | Typing in notes | Batches disk writes. |
| Now-playing progress bar | Redraw at 1 Hz (SwiftUI `TimelineView`) | Expanded view visible **and** playing | Progress is extrapolated; redraws only while someone is looking. |
| Decorative waveform | ≤ 30 fps animation | Compact view visible **and** playing **and** not Low Power Mode | Animation. Static bars otherwise. |

Not allowed: any repeating timer while idle, a hover polling loop, a memory watchdog, a Bluetooth poll. These are the loops Atoll runs that we avoid [V: research/atoll-system-shell.md B12].

## 10. Logging and privacy

- `os.Logger(subsystem: "com.shashwat.DropNotch", category: "<Module>")` [V: CLAUDE.md]. Never log clipboard content, file names or track info. Dynamic strings and objects are redacted by default, but integers, floats and booleans are not [V: https://developer.apple.com/documentation/os/generating-log-messages-from-your-code], so mark anything sensitive `privacy: .private` explicitly.
- No network calls in the MVP. Lyrics, weather and updates are later features, and each one comes with privacy copy that says what it sends.
- Each permission is requested when its feature is first enabled, never at launch.
