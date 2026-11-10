# DropNotch

Turns the MacBook notch into a productivity surface.

[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](#requirements)
[![Release: v0.1.0 pre-release](https://img.shields.io/badge/release-v0.1.0%20pre--release-orange)](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.1.0)
[![Swift 5](https://img.shields.io/badge/swift-5-F05138)](project.yml)

[![Download DropNotch 0.1.0](https://img.shields.io/badge/Download-DropNotch%200.1.0-2ea44f)](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.1.0)

Pre-release: not yet notarised. Follow the first-launch steps under [Install](#install).

<!-- TODO(screenshots): no images exist in docs/ or assets/ yet. Add a screenshot or GIF of the open notch here
     (suggested: docs/images/notch-open.png), and one of the DMG window, once they are captured. -->

DropNotch is an open-source macOS utility. The notch opens when you hover over it, or when you press ⌃⌥N, and stays minimal otherwise.

## Features

- **Now Playing** for Apple Music and Spotify: title, artist, artwork, a progress bar you can seek, and play/pause, next and previous. While music plays, the closed notch widens to show the artwork and small animated bars (decorative).
- **Notes:** one plain-text note, saved automatically about a second after you stop typing.
- **File tray:** drop files on the notch, drag them out again, or send them with AirDrop or Share. Most dropped files stay where they are and the tray keeps a link to them; items with no file behind them, such as an image dragged from Photos or Mail, are copied into the tray.
- **Clipboard history:** off until you turn it on. Keeps the last 25 text, link and image items, with search; click an item or press Return to copy it back.
- **Terminal:** off until you turn it on. Your login shell in the notch, like Terminal.app: it starts when you open the tab, keeps running while the notch is closed, and ends with End Session. Click in it (or press ⌃⌥N) to type; font size and scrollback are in Settings › Terminal.
- **Hotkey:** ⌃⌥N opens and closes the notch with keyboard focus, and can be changed in Settings. While the notch has keyboard focus, ⌘1, ⌘2… switch tabs and ⌘, opens Settings. In Now Playing, Tray and Clipboard, Tab moves between controls and Space or Return presses them. The arrow keys also step through Now Playing's controls and the tray's files and buttons (only Tab reaches Clear All), and ↑/↓ choose a clipboard item.
- **Notch size:** Standard, or Large in Settings › General: taller and wider, with larger text, artwork and rows on every tab.
- **Customisable modules:** in Settings, turn modules on or off, reorder the tabs, choose what fills each side of the closed notch, set launch at login, and choose the built-in or main display.

## Install

1. Download `DropNotch-0.1.0.dmg` and `DropNotch-0.1.0.dmg.sha256` from the [release page](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.1.0).
2. Open the DMG and drag **DropNotch** onto **Applications**.
3. Open DropNotch. It is not notarised, so macOS blocks the first launch. On macOS 27.0.1 the dialog is titled "“DropNotch.app” Not Opened" and says "Apple could not verify “DropNotch.app” is free of malware that may harm your Mac or compromise your privacy." Its buttons are **Done** and **Move to Bin** (**Move to Trash** in US English). Click **Done**. Then, as [Apple documents](https://support.apple.com/en-us/102445): open System Settings, click Privacy & Security, scroll down and click **Open Anyway**. When the warning reappears, click **Open**. macOS saves this as an exception. Wording may differ on other macOS versions.
4. Click a playback control. macOS asks whether DropNotch may control Music or Spotify; allow it. Without that, the title and artist show but the controls, artwork and seeking don't. To change your answer later, use System Settings › Privacy & Security › Automation.

DropNotch has no Dock icon. Look for it in the menu bar, hover over the notch, or press ⌃⌥N. To uninstall, quit it from the menu-bar item and move it from Applications to the Trash. Its data is in `~/Library/Application Support/DropNotch` and its settings in `~/Library/Preferences/com.shashwat.DropNotch.plist`; remove those too if you want no trace.

### Verify the download

Keep both downloaded files in one folder and run:

```sh
cd ~/Downloads && shasum -a 256 -c DropNotch-0.1.0.dmg.sha256
```

It must print `DropNotch-0.1.0.dmg: OK`. While releases are unsigned, this is the only check that the file is the one published.

## Requirements

- macOS 14.0 or later.
- A MacBook with a notch is recommended. On a display without one, DropNotch draws a pill at the top of the screen instead.
- Tested only on Apple silicon. The build also contains an Intel (x86_64) slice, which has not been tested.
- Measured on one Mac with the Release build, notch closed and clipboard history on, over 60 seconds: 0.0 % CPU, a 21 MB memory footprint and no network traffic. Other states, such as the notch open while music plays, have not been measured yet.

## Privacy and permissions

- No analytics or telemetry. The only network request is Spotify's cover image over HTTPS from `i.scdn.co`, made when a new Spotify track starts. Turn it off in Settings › Privacy. Music's artwork needs no network. (The GitHub link in Settings › About opens your browser.)
- Clipboard history is off until you turn it on in its tab. It skips items that password managers and other apps mark as concealed or transient. It stays in memory, unless you turn on Keep history after quitting in Settings › Privacy, which saves text and links (not images) to `~/Library/Application Support/DropNotch/clipboard.json`. Logs never contain clipboard contents, file names or track details. The open Clipboard tab shows your history to anyone who can see your screen.
- **Terminal:** the first time you turn it on, Settings shows what it can use and asks you to confirm; Settings › Terminal keeps showing it. Commands you run in the Terminal tab use DropNotch's permissions, as they would in the terminal in VS Code or iTerm: Calendars (full access, which can change events), the Desktop, Documents and Downloads folders, and controlling other apps, wherever you've allowed them. If a command needs something else, macOS asks in DropNotch's name, and what you allow stays allowed for DropNotch. Your shell's setup files and the tools they run get the same permissions, and jobs you start with `nohup` or `disown` keep running after the session ends and after DropNotch quits. Programs in the terminal can't read or change your clipboard; ⌘C and ⌘V work as usual. While the terminal has your keys, secure keyboard entry is on, so other apps can't read what you type; text expanders and other tools that watch the keyboard pause until you click elsewhere, and macOS may name the app in front as the one holding it. DropNotch never records what you type or what the terminal shows; your shell keeps its own history (`~/.zsh_history`). The open tab shows its output to anyone who can see your screen. A paste of several lines into a program that hasn't asked for bracketed paste runs each line, as in other terminals.
- The tray keeps a link to each file it doesn't copy, and the link includes the path. Removing an item or Clear All deletes only the tray's own copies, never your originals.
- DropNotch is **not sandboxed** ([D4](docs/DECISIONS.md)). It runs with the hardened runtime and two entitlements: `com.apple.security.automation.apple-events`, which lets it send commands to Music and Spotify, and `com.apple.security.personal-information.calendars`, which lets the Calendar card read your upcoming events: today's, and tomorrow's first one ([D44](docs/DECISIONS.md)).
- The Calendar card shows every calendar, including ones you hid in Calendar. The open card shows event titles to anyone who can see your screen; turn off Show event titles in Settings › Privacy before sharing it.
- macOS asks for a permission only when you first use the feature that needs it: Automation (Music, Spotify); Calendars, when you click Allow Calendar on the Home tab's Calendar card or turn the card on in Settings (macOS calls it full access; the Calendar card only reads, and Settings › Privacy can hide event titles, but commands in the Terminal tab can also add, change or delete events); Desktop, Documents or Downloads, when the tray first accesses a file in one of them; Paste from Other Apps, if you turn on clipboard history (under Always Allow it reads automatically, otherwise the tab offers Add Clipboard and macOS asks when you click it); Login Items, if you turn on Launch at login; Local Network, only if a command in the Terminal tab looks for devices on your network. Not every prompt has been checked on a device yet.

## Build from source

You need Xcode 27 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). `DropNotch.xcodeproj` is generated from `project.yml` and is not committed.

```sh
xcodegen generate
xcodebuild -scheme DropNotch -destination 'platform=macOS' -skipPackagePluginValidation build test
```

Run `xcodegen generate` again after adding or removing files. The first build fetches the KeyboardShortcuts and SwiftTerm packages. SwiftTerm runs a small build plugin, so `xcodebuild` needs `-skipPackagePluginValidation` and Xcode asks you to "Trust & Enable" it once. `scripts/make-dmg.sh` first checks every package resolved to the commit listed in `scripts/Package.resolved.expected`. Local builds are ad-hoc signed. To make the release DMG, run `brew install create-dmg` once, then `scripts/make-dmg.sh`; it writes `build/DropNotch-<version>.dmg` and its `.sha256` file.

## Roadmap

Planned for v0.2, not started: a Home dashboard with a music card, calendar, battery and terminal (the terminal needs a dependency and a security review first), Developer ID signing and notarisation, and automatic updates. The full plan is in [docs/FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md).

## Contributing

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`), one feature per branch named `feat/<name>`. Decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md), and the structure is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Do not copy code, assets or UI text from GPL-licensed apps (see the clean-room statement below). Maintainers: [docs/RELEASING.md](docs/RELEASING.md).

## Licence

DropNotch is released under the MIT licence. See [LICENSE](LICENSE).

## Acknowledgements

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 3.1.0 by Sindre Sorhus (MIT) powers the hotkey recorder. Its licence is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Clean-room statement: DropNotch's code is original. The GPL-3.0 apps Atoll and Boring Notch were read only to learn which APIs and techniques notch apps use, and no code, assets or UI text was copied from them. Canopy is closed source; only its public web pages were used. Technique notes written in our own words are in [docs/research/](docs/research/).
