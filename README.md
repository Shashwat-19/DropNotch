# DropNotch

Turns the MacBook notch into a productivity surface.

[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](#requirements)
[![Release: v0.2.0 pre-release](https://img.shields.io/badge/release-v0.2.0%20pre--release-orange)](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.2.0)
[![Swift 5](https://img.shields.io/badge/swift-5-F05138)](project.yml)

[![Download DropNotch 0.2.0](https://img.shields.io/badge/Download-DropNotch%200.2.0-2ea44f)](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.2.0)

Pre-release: not yet notarised. Follow the first-launch steps under [Install](#install).

<!-- TODO(screenshots): no images exist in docs/ or assets/ yet. Add a screenshot or GIF of the open notch here
     (suggested: docs/images/notch-open.png), and one of the DMG window, once they are captured. -->

DropNotch is an open-source macOS utility. The notch opens when you hover over it, or when you press ⌃⌥N, and stays minimal otherwise. Moving the pointer away closes it: after 0.5 s while it has keyboard focus (the terminal, a note or Clipboard search), otherwise after 0.1 s, and never while you are dragging with the button held.

## Features

- **Home tab,** the first tab: cards side by side, chosen and ordered in Settings › Modules.
  - **Now Playing** for Apple Music and Spotify: title, artist, artwork, a progress bar you can seek with the elapsed and total time under it, and play/pause, next and previous. While music plays, the closed notch widens to show the artwork and small animated bars (decorative).
  - **Calendar:** today's all-day events and the events still to come, then tomorrow's first event once today's are over. A click opens Calendar. Until you give access, the card shows Allow Calendar (see [Privacy and permissions](#privacy-and-permissions)).
  - **Battery,** off until you turn it on, and only on Macs with a battery: the charge in a ring, Charging or On power, and a warning colour below 20 %.
- **Notes:** one plain-text note, saved automatically about a second after you stop typing.
- **File tray:** drop files on the notch, drag them out again, or send them with AirDrop or Share. Most dropped files stay where they are and the tray keeps a link to them; items with no file behind them, such as an image dragged from Photos or Mail, are copied into the tray.
- **Clipboard history:** off until you turn it on. Keeps the last 25 text, link and image items, with search; click an item or press Return to copy it back.
- **Terminal:** off until you turn it on. Your login shell in the notch, like Terminal.app. The shell starts only when you open it on purpose (a click on the tab, its ⌘ number, ⌃⌥N on the Terminal tab, or Start Session), never when the notch opens on hover. It keeps running while the notch is closed and ends with End Session. The terminal takes your keys after a click in it, a click on its tab, its ⌘ number or ⌃⌥N. Settings › Terminal › Type as soon as the notch opens also gives it the keys on hover (off by default, as a stray Return can run a command); even then a hover doesn't start the shell. Font size and scrollback are in Settings › Terminal.
- **Hotkey:** ⌃⌥N opens and closes the notch with keyboard focus, and can be changed in Settings. While the notch has keyboard focus, ⌘1, ⌘2… switch tabs and ⌘, opens Settings. On Home's Now Playing card, in Tray and in Clipboard, Tab moves between controls and Space or Return presses them. The arrow keys also step through Now Playing's controls and the tray's files and buttons (only Tab reaches Clear All), and ↑/↓ choose a clipboard item.
- **Notch size:** Standard (the default), or Large in Settings › General: 40 pt taller and 80 pt wider, with larger text, artwork and controls on every tab (the terminal keeps its own font size and gets more rows and columns).
- **Customisable modules:** in Settings, turn tabs and Home cards on or off, reorder them, choose what fills each side of the closed notch, set launch at login, and choose the built-in or main display.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask shashwat-19/tap/dropnotch
```

Then follow step 3 below for the first launch. Or install the DMG by hand:

1. Download `DropNotch-0.2.0.dmg` and `DropNotch-0.2.0.dmg.sha256` from the [release page](https://github.com/Shashwat-19/DropNotch/releases/tag/v0.2.0). If you are updating, quit DropNotch from its menu-bar item first.
2. Open the DMG and drag **DropNotch** onto **Applications** (replace the old copy if asked).
3. Open DropNotch. It is not notarised, so macOS blocks the first launch. On macOS 27.0.1 the dialog is titled "“DropNotch.app” Not Opened" and says "Apple could not verify “DropNotch.app” is free of malware that may harm your Mac or compromise your privacy." Its buttons are **Done** and **Move to Bin** (**Move to Trash** in US English). Click **Done**. Then, as [Apple documents](https://support.apple.com/en-us/102445): open System Settings, click Privacy & Security, scroll down and click **Open Anyway**. When the warning reappears, click **Open**. macOS saves this as an exception. Wording may differ on other macOS versions.
4. Click a playback control on the Home tab's Now Playing card. macOS asks whether DropNotch may control Music or Spotify; allow it. Without that, the title and artist show but the controls, artwork and seeking don't. To change your answer later, use System Settings › Privacy & Security › Automation.

Updating from 0.1.0: this build isn't signed with a Developer ID, so macOS may treat it as a new app and ask again for Music or Spotify control. If the controls stop working, turn DropNotch back on in System Settings › Privacy & Security › Automation.

DropNotch has no Dock icon. Look for it in the menu bar, hover over the notch, or press ⌃⌥N. To uninstall, quit it from the menu-bar item and move it from Applications to the Bin (Trash in US English). Its data is in `~/Library/Application Support/DropNotch` and its settings in `~/Library/Preferences/com.shashwat.DropNotch.plist`; remove those too. Its privacy permissions stay in System Settings until you reset them with `tccutil reset All com.shashwat.DropNotch`, and commands you typed in the Terminal tab stay in your shell's history.

### Verify the download

Keep both downloaded files in one folder and run:

```sh
cd ~/Downloads && shasum -a 256 -c DropNotch-0.2.0.dmg.sha256
```

It must print `DropNotch-0.2.0.dmg: OK`. While releases are unsigned, this is the only check that the file is the one published.

## Requirements

- macOS 14.0 or later.
- A MacBook with a notch is recommended. On a display without one, DropNotch draws a pill at the top of the screen instead.
- Tested only on Apple silicon. The build also contains an Intel (x86_64) slice, which has not been tested.
- Measured for 0.1.0 on one Mac with the Release build, notch closed and clipboard history on, over 60 seconds: 0.0 % CPU, a 21 MB memory footprint and no network traffic. Not measured again for 0.2.0, and other states, such as the notch open while music plays or an idle terminal session, have not been measured yet.

## Privacy and permissions

- No analytics or telemetry. The only network request DropNotch itself makes is Spotify's cover image over HTTPS from `i.scdn.co`, made when a new Spotify track starts. Turn it off in Settings › Privacy. Music's artwork needs no network, and calendar events never leave the Mac. (The GitHub link in Settings › About opens your browser.) Commands you run in the Terminal tab can use the network like any other terminal.
- Clipboard history is off until you turn it on in its tab. It skips items that password managers and other apps mark as concealed or transient. It stays in memory, unless you turn on Keep history after quitting in Settings › Privacy, which saves text and links (not images) to `~/Library/Application Support/DropNotch/clipboard.json`. Logs never contain clipboard contents, file names, track details, event titles or anything typed or shown in the terminal. The open Clipboard tab shows your history to anyone who can see your screen.
- DropNotch's data folder, `~/Library/Application Support/DropNotch`, can be opened only by your account, and the tray list and note can be read only by you.
- **Terminal:** the first time you turn it on, Settings shows what it can use and asks you to confirm; Cancel leaves it off. Settings › Terminal keeps showing the same text. Commands you run in the Terminal tab use DropNotch's permissions, as they would in the terminal in VS Code or iTerm: Calendars (full access, which can change events), the Desktop, Documents and Downloads folders, and controlling other apps, wherever you've allowed them. If a command needs something else, macOS asks in DropNotch's name, and what you allow stays allowed for DropNotch. Your shell's setup files and the tools they run get the same permissions every time a session starts, and jobs you start with `nohup` or `disown` keep running, with those permissions, after the session ends and after DropNotch quits. To stop this, turn Terminal off in Settings › Modules and end any jobs you left running. Programs in the terminal can't read or change your clipboard; ⌘C and ⌘V work as usual. While the terminal has your keys, secure keyboard entry is on, so other apps can't read what you type; text expanders and other tools that watch the keyboard pause until you click elsewhere. DropNotch never records what you type or what the terminal shows; your shell keeps its own history (for zsh, `~/.zsh_history`). The open tab shows its output to anyone who can see your screen. If you keep typing after the pointer has been off the notch for more than 0.5 s, the notch closes and your typing goes to the app in front. A paste of several lines into a program that hasn't asked for bracketed paste runs each line, as in other terminals.
- The tray keeps a link to each file it doesn't copy, and the link includes the path. Removing an item or Clear All deletes only the tray's own copies, never your originals.
- DropNotch is **not sandboxed** ([D4](docs/DECISIONS.md)). It runs with the hardened runtime and two entitlements: `com.apple.security.automation.apple-events`, which lets it send commands to Music and Spotify, and `com.apple.security.personal-information.calendars`, which lets the Calendar card read your upcoming events: today's, and tomorrow's first one ([D44](docs/DECISIONS.md)).
- The Calendar card shows every calendar, including ones you hid in Calendar. The open card shows event titles to anyone who can see your screen; turn off Show event titles in Settings › Privacy before sharing it.
- macOS asks for a permission only when you first use the feature that needs it, never at launch:
  - Automation (Music, Spotify): the first time you use a playback control or the progress bar. A command in the Terminal tab that controls another app causes its own Automation prompt.
  - Calendars: when you click Allow Calendar on the Home tab's Calendar card, or turn the card on in Settings. macOS calls it full access; the Calendar card only reads, and Settings › Privacy can hide event titles, but commands in the Terminal tab can also add, change or delete events.
  - Desktop, Documents or Downloads: when the tray first accesses a file in one of them, or a command in the Terminal tab does.
  - Paste from Other Apps: if you turn on clipboard history. Under Always Allow it reads automatically; otherwise the tab offers Add Clipboard and macOS asks when you click it.
  - Login Items: if you turn on Launch at login.
  - Local Network: only if a command in the Terminal tab looks for devices on your network. DropNotch itself never uses your local network.

  The Calendars, Desktop, Documents, Downloads and Automation prompts mention the Terminal tab, because a command run there may be the one asking. Not every prompt has been checked on a device yet.

## Build from source

You need Xcode 27 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). `DropNotch.xcodeproj` is generated from `project.yml` and is not committed.

```sh
xcodegen generate
xcodebuild -scheme DropNotch -destination 'platform=macOS' -skipPackagePluginValidation build test
```

Run `xcodegen generate` again after adding or removing files. The first build fetches the KeyboardShortcuts and SwiftTerm packages. SwiftTerm runs a small build plugin, so `xcodebuild` needs `-skipPackagePluginValidation` and Xcode asks you to "Trust & Enable" it once. Local builds are ad-hoc signed. To make the release DMG, run `brew install create-dmg` once, then `scripts/make-dmg.sh`. It first checks that every package resolved to the commit listed in `scripts/Package.resolved.expected`, builds only those versions, and writes `build/DropNotch-<version>.dmg` and its `.sha256` file.

## Roadmap

0.2.0 added the Home tab with Now Playing, Calendar and Battery cards, the Terminal tab and the Large notch size. Still planned, with no version set: Developer ID signing and notarisation (they need an Apple Developer account), and automatic updates, which need signing first. Until then, check [GitHub Releases](https://github.com/Shashwat-19/DropNotch/releases) for new versions. Other ideas and their status are in [docs/FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md).

## Contributing

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`), one feature per branch named `feat/<name>`. Decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md), and the structure is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Do not copy code, assets or UI text from GPL-licensed apps (see the clean-room statement below). Maintainers: [docs/RELEASING.md](docs/RELEASING.md).

## Licence

DropNotch is released under the MIT licence. See [LICENSE](LICENSE).

## Acknowledgements

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 3.1.0 by Sindre Sorhus (MIT) powers the hotkey recorder.
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 1.99.3 by Miguel de Icaza and contributors (MIT) powers the Terminal tab.
- Both licences are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Clean-room statement: DropNotch's code is original. The GPL-3.0 apps Atoll and Boring Notch were read only to learn which APIs and techniques notch apps use, and no code, assets or UI text was copied from them. Canopy is closed source; only its public web pages were used. Technique notes written in our own words are in [docs/research/](docs/research/).
