# Changelog

All notable changes to DropNotch are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and DropNotch uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-13

A lock-screen player, synced lyrics, a weather card and a few touches from Canopy's list; still an early, unsigned build for macOS 14 or later, tested on Apple silicon.

New permissions and network use. As before, macOS asks only when you first turn on the feature that needs it, and every new feature that talks to the internet is off until you turn it on:
- **Bluetooth (new):** only when you turn on Settings › General › Show headphone battery when they connect. DropNotch only reads the battery levels of AirPods and other headphones; it never connects to or changes a device.
- **Weather (off by default):** searching for a city sends what you type to Open-Meteo's geocoding service; after that, only the city's coordinates, rounded to about 1 km, go to Open-Meteo's weather and air-quality services, when the Weather card shows and its reading is more than 30 minutes old. No account and no Location permission.
- **Synced lyrics (off by default):** sends the track's title, artist and length to LRCLIB (lrclib.net) once per track, only while the Now Playing card or the lock-screen player shows them. Lyrics stay in memory and are never saved or logged.
- **Lock-screen player (off by default):** while your Mac is locked, anyone at it can see what's playing and use play, pause, skip and seek. It uses private parts of macOS to draw over the lock screen, so a macOS update may turn it off.
- Updating from 0.2.0: this build isn't signed with a Developer ID, so macOS may ask again for Music or Spotify control.

### Added
- Lock-screen player, off by default (Settings › General): a small glass player above your avatar and password while the Mac is locked and a track is loaded. Click the artwork, the title or the lyrics button for the full screen: the artwork, the player and the lyrics; × goes back to the small player.
- Synced lyrics from LRCLIB, off by default (Settings › Privacy): the current line in the Now Playing card, and the full lyrics on the lock screen, lighting word by word.
- Weather card on Home, off by default: temperature in your unit, today's high and low, and air quality (US AQI) in words, for a city you choose in the new Settings › Weather.
- Charging alert: the closed notch shows a bolt and the charge for 3 seconds when you plug in (Settings › General; on by default on Macs with a battery).
- Headphone battery alert, off by default: the closed notch shows your AirPods' battery when they connect.
- Haptic feedback: a light tap on the trackpad with each alert, if a finger is on it (Settings › General).
- Round the bottom corners of the screen, off by default (Settings › General), to match the built-in display's rounded top corners. Clicks in the corners still reach what's underneath.
- Settings › General › Look: Liquid Glass for the open notch on macOS 26 or later. The closed notch stays black; Reduce Transparency keeps it black.
- VoiceOver announces alerts in the notch.

### Changed
- With Calendar, Battery and Weather all on, the Home cards shrink so the Now Playing card keeps at least 30 % of the row.
- Artwork is kept at a higher resolution, so it's sharp on the lock screen.

### Known issues
- This build still isn't signed with an Apple Developer ID or notarised, so macOS blocks it the first time you open it; follow the Open Anyway steps in [README › Install](README.md#install).
- The full-screen lock-screen view covers the password prompt; collapse it with × or unlock with Touch ID.
- The lock-screen player's position was tuned on a MacBook Air; on other Macs or with a second display it may sit too high or low.
- Lyrics light word by word at an even pace across each line, as LRCLIB gives line timings only.
- DropNotch needs macOS 14 or later. It has only been tested on Apple silicon Macs.

## [0.2.0] - 2026-11-10

A Home tab with cards, an optional Terminal tab, a taller notch and a Large size; still an early, unsigned build for macOS 14 or later, tested on Apple silicon.

New permissions and prompts. As before, macOS asks only when you first use the feature that needs it, never at launch:
- **Calendars (new):** only when you click Allow Calendar on the Home tab's Calendar card, or turn the card on in Settings. macOS calls it full access; the Calendar card only reads your events.
- **Terminal tab (off by default):** the first time you turn it on, Settings shows what it can use and asks you to confirm; Settings › Terminal keeps showing it. Commands you run in the Terminal tab use DropNotch's permissions, as they would in the terminal in VS Code or iTerm: Calendars (full access, which can change events), the Desktop, Documents and Downloads folders, and controlling other apps, wherever you've allowed them. If a command needs something else, macOS asks in DropNotch's name, and what you allow stays allowed for DropNotch.
- **Local Network (new):** only if a command in the Terminal tab looks for devices on your network. DropNotch itself never uses your local network.
- The Calendars, Desktop, Documents, Downloads and Automation prompts now mention the Terminal tab, because a command run there may be the one asking.
- DropNotch now has two entitlements: Apple Events (to control Music and Spotify, as before) and Calendars (new, for the Calendar card). It is still not sandboxed.
- Updating from 0.1.0: this build isn't signed with a Developer ID, so macOS may treat it as a new app and ask again for Music or Spotify control. If the controls stop working, turn DropNotch back on in System Settings › Privacy & Security › Automation.

### Added
- Home tab, now the first tab: cards side by side, chosen and ordered in Settings › Modules.
- Now Playing card on Home, with larger artwork and the elapsed and total time under the progress bar.
- Calendar card: today's all-day events and the events still to come, then tomorrow's first event once today's are over; a click opens Calendar.
- Settings › Privacy › Show event titles: turn it off to show only times on the Calendar card.
- Battery card, off by default: charge percentage in a ring, Charging or On power, and a warning colour below 20 %. Only on Macs with a battery.
- Terminal tab, off by default: your login shell in the notch, like Terminal.app. It starts only when you open the tab on purpose (a click on the tab, its ⌘ number, ⌃⌥N on the Terminal tab, or Start Session), never on hover, and keeps running while the notch is closed.
- The terminal takes your keys after a click in it, a click on its tab, its ⌘ number or ⌃⌥N; Settings › Terminal › Type as soon as the notch opens also gives it the keys on hover (off by default, as a stray Return can run a command).
- End Session ends the shell and anything running in it, without asking; Start New Session begins a fresh one.
- Settings › Terminal: font size (10–14 pt), scrollback (1,000, 5,000 or 10,000 lines) and the permissions text.
- Programs in the terminal can't read or change your clipboard; ⌘C and ⌘V work as usual.
- While the terminal has your keys, secure keyboard entry is on, so other apps can't read what you type; text expanders and other keyboard tools pause until you click elsewhere.
- Settings › General › Notch size: Standard (the default) or Large. Large is taller and wider, with larger text, artwork and controls on every tab; the terminal keeps its font size and gets more rows and columns.

### Changed
- The open notch is 40 pt taller (190 pt) on every tab, so the Calendar card and Clipboard show five rows on a MacBook Air.
- Now Playing no longer has its own tab: it is the wide card on Home, so ⌘1 is Home and ⌘2 is Notes. The compact view while music plays is unchanged.
- Settings › Modules lists Tabs and Home cards in separate sections; the arrows reorder within a section.
- The open notch widens to fit the tabs you have turned on, so it is wider with Terminal on.
- Moving the pointer away now always closes the notch: after 0.1 s, or 0.5 s while it has keyboard focus (the terminal, a note or Clipboard search), and not while you are dragging with the button held. Before, a notch with keyboard focus stayed open until Escape or a click elsewhere. A terminal session keeps running.
- DropNotch's data folder, `~/Library/Application Support/DropNotch`, is now private to your account, and the tray list and note can be read only by you. Before, other accounts on the same Mac could list the tray and read the note.

### Known issues
- This build still isn't signed with an Apple Developer ID or notarised, so macOS blocks it the first time you open it; follow the Open Anyway steps in [README › Install](README.md#install).
- DropNotch needs macOS 14 or later. It has only been tested on Apple silicon Macs; the build also contains an Intel slice that hasn't been tested.
- Jobs you start in the terminal with `nohup` or `disown` keep running after the session ends and after DropNotch quits, with DropNotch's permissions.
- Your shell's setup files, and the tools they run, get DropNotch's permissions every time a session starts.
- The Terminal tab shows its output to anyone who can see your screen.
- If you keep typing after the pointer has been off the notch for more than 0.5 s, the notch closes and your typing goes to the app in front.
- The Calendar card shows every calendar, including ones you hid in Calendar, and its titles are visible to anyone who can see your screen; turn off Show event titles before sharing your screen.
- Clear All empties the tray straight away, with no confirmation or undo; your original files are never touched.
- VoiceOver finds nothing in the closed notch; press ⌃⌥N to open it instead.
- Now Playing relies on notifications that Music and Spotify don't document, so a player update could stop track details appearing; the controls would still work.
- Not yet checked on a real Mac: VoiceOver on the Home tab and the Battery card, Home with Larger Text, Spotify's progress bar, seeking, artwork and ads, which network requests are made, and energy and memory use (including the terminal's wake-ups while idle). The accessibility and performance reviews weren't repeated for this version, and the earlier accessibility findings (the File Tray's keyboard path, VoiceOver in the closed notch) haven't been re-checked on a device. Expect some rough edges.
- There are no automatic updates yet: check GitHub Releases for new versions.

## [0.1.0] - 2026-11-01

The first release: an early build for macOS 14 or later, tested on Apple silicon.

macOS asks for each permission only when you first use the feature that needs it, never at launch:
- **Automation (Music, Spotify):** the first time you use a playback control or the progress bar.
- **Files and folders (Desktop, Documents, Downloads):** once per folder, when the tray first opens a file from it.
- **Paste from Other Apps:** when you click Add Clipboard, unless DropNotch is set to Always Allow.
- **Login Items:** only if you turn on Launch at login.

### Added
- The notch opens when you hover over it and stays minimal otherwise.
- Now Playing for Apple Music and Spotify: title, artist and artwork, play/pause, next and previous, and a progress bar you can click or drag to seek.
- Compact view: while music plays, the closed notch widens to show the artwork on one side and animated bars on the other; either side can be set to Nothing.
- Notes: one plain-text note, saved as you type.
- File tray: drop files on the notch to keep them at hand, then drag them out, send them with AirDrop or share them; your files stay where they are.
- Clipboard history, off until you turn it on: the last 25 text, link and image items, and a click copies one back.
- Option to keep clipboard text and links after quitting, stored only on your Mac.
- Hotkey ⌃⌥N opens and closes the notch with keyboard focus; ⌘1, ⌘2… switch tabs and ⌘, opens Settings.
- Keyboard access in Now Playing, Tray and Clipboard: Tab and the arrow keys move between controls, and Space or Return presses them.
- Settings window: launch at login, the hotkey, which display shows the notch, module order and on/off, what fills each side of the closed notch, and privacy options.
- Menu-bar item with Settings and Quit; DropNotch has no Dock icon.
- No analytics or telemetry; the only network request downloads Spotify artwork, and you can turn it off in Settings › Privacy.

### Known issues
- This build isn't signed with an Apple Developer ID or notarised, so macOS blocks it the first time you open it; follow the Open Anyway steps in [README › Install](README.md#install).
- DropNotch needs macOS 14 or later. It has only been tested on Apple silicon Macs; the build also contains an Intel slice that hasn't been tested.
- Clear All empties the tray straight away, with no confirmation or undo, including Space once Tab has reached it; your original files are never touched.
- VoiceOver finds nothing in the closed notch; press ⌃⌥N to open it instead.
- Not every check on a real Mac has been run yet, so expect some rough edges.
- Now Playing relies on notifications that Music and Spotify don't document, so a player update could stop track details appearing; the controls would still work.
- There are no automatic updates yet: check GitHub Releases for new versions.

[0.3.0]: https://github.com/Shashwat-19/DropNotch/releases/tag/v0.3.0
[0.2.0]: https://github.com/Shashwat-19/DropNotch/releases/tag/v0.2.0
[0.1.0]: https://github.com/Shashwat-19/DropNotch/releases/tag/v0.1.0
