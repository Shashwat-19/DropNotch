# Changelog

All notable changes to DropNotch are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and DropNotch uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-01

The first release: an early build for macOS 14 or later on Apple silicon.

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
- This build isn't signed with an Apple Developer ID or notarised, so macOS blocks it the first time you open it; follow the Open Anyway steps in [README › Install](README.md#install), once for each new version.
- DropNotch runs only on macOS 14 or later on Apple silicon Macs.
- Clear All empties the tray straight away, with no confirmation or undo, including Space once Tab has reached it; your original files are never touched.
- VoiceOver finds nothing in the closed notch; press ⌃⌥N to open it instead.
- Not every check on a real Mac has been run yet, so expect some rough edges.
- Now Playing relies on notifications that Music and Spotify don't document, so a player update could stop track details appearing; the controls would still work.
- There are no automatic updates yet: check GitHub Releases for new versions.

[0.1.0]: https://github.com/Shashwat-19/DropNotch/releases/tag/v0.1.0
