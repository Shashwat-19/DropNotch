# DropNotch

DropNotch is an open-source macOS utility that turns the MacBook notch into a productivity surface. The notch opens when you hover over it and stays minimal otherwise.

What works today:
- **Now Playing** for Apple Music and Spotify: the current title and artist, with artwork, a progress bar you can seek, and play/pause, next and previous controls.
- **Compact view:** while music plays, the closed notch widens a little on each side that has something to show. By default that is the artwork on the left and small animated bars on the right; either side can be set to Nothing in Settings.
- **Notes:** one plain-text note, saved as you type.
- **File tray:** drop files on the notch to keep them at hand, then drag them out again, send them with AirDrop or share them. Dropped files stay where they are; the tray keeps a link to them.
- **Clipboard history:** off until you turn it on in its tab. Keeps the last 25 text, link and image items; click one to copy it back.
- **Hotkey:** ⌃⌥N opens and closes the notch with keyboard focus. ⌘1, ⌘2… switch tabs and ⌘, opens Settings while the notch has focus.

Each module has its own tab in the open notch, next to a Settings button.

Planned, not built yet: signed releases, automatic updates and per-module settings.

## Status

Pre-alpha. Some checks on a real Mac are still outstanding, including how the Automation permission behaves (see [Permissions](#permissions)). The plans are in:

- [docs/FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/DECISIONS.md](docs/DECISIONS.md)

## Install

Download `DropNotch-0.1.0.dmg` from [GitHub Releases](https://github.com/Shashwat-19/DropNotch/releases). DropNotch needs macOS 14 or later on an Apple silicon Mac.

1. Open the DMG and drag **DropNotch** onto **Applications**.
2. Open DropNotch from Applications.

DropNotch isn't signed with an Apple Developer ID yet, so the first time you open it, macOS blocks it. On macOS 15 or later:

1. macOS says "DropNotch" Not Opened. Click **Done** (not Move to Trash).
2. Open **System Settings › Privacy & Security** and scroll down to **Security**. Next to "DropNotch" was blocked to protect your Mac, click **Open Anyway**. The button shows for about an hour after you try to open the app.
3. Click **Open Anyway** again in the dialog, then enter your password or use Touch ID.

On macOS 14, Control-click DropNotch in Applications, choose **Open**, then click **Open** again.

macOS remembers the choice, so later launches open normally. Downloading a new version means doing this once more.

DropNotch has no Dock icon: look for it in the menu bar, and hover over the notch or press ⌃⌥N.

To uninstall, quit DropNotch from its menu-bar item and move it from Applications to the Trash. Its tray, note and saved clipboard live in `~/Library/Application Support/DropNotch`, and its settings in `~/Library/Preferences/com.shashwat.DropNotch.plist`.

## Settings

Open Settings from the DropNotch menu-bar item, or with the gear button in the open notch.

- **General:** launch at login, the hotkey, and which display shows the notch (the built-in display, or the main display).
- **Modules:** turn each module on or off, change the tab order, and choose what fills each side of the closed notch (Now Playing or Nothing). Modules that are off are greyed and move to the bottom of the list.
- **Privacy:** Spotify artwork downloads, clipboard history on or off, keep clipboard history after quitting, clear the clipboard history, clear the tray.
- **About:** version, licence and third-party notices.

## Requirements

- To run: macOS 14.0 or later.
- To build: Xcode 27 or later, and XcodeGen.

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Build from source

1. Clone this repository.
2. Generate the Xcode project from `project.yml`:

   ```sh
   xcodegen generate
   ```

   `DropNotch.xcodeproj` is generated and is not committed. Run this step before you open the project or build it, and again after adding or removing files.

3. Open `DropNotch.xcodeproj` in Xcode, or build and test from the command line:

   ```sh
   xcodebuild -scheme DropNotch -destination 'platform=macOS' build test
   ```

The first build fetches the KeyboardShortcuts Swift package, which Xcode resolves automatically.

Builds are ad-hoc signed for local use. There are no signed or notarised releases yet.

## Permissions

DropNotch asks for a permission only when you first use the feature that needs it, never at launch.

**Automation (Music, Spotify).** Needed for the play/pause, next, previous and seek controls. macOS asks the first time you click one of these controls for Music or Spotify. The title and artist appear without this permission. The controls, the artwork, Music's progress bar and seeking need it. (Without it, a track that is already playing when DropNotch starts shows only the player's name until the next track change.)

If you choose Don't Allow, the notch shows "Allow control of Music (or Spotify) in System Settings". To allow it later, open System Settings › Privacy & Security › Automation, find DropNotch and turn on Music or Spotify.

**Files and folders (Desktop, Documents, Downloads).** The file tray keeps a link to each file you drop. macOS may ask once per folder when the tray first opens a file from one of these folders: when you drop it, or when you open the Tray tab.

**Paste from Other Apps (macOS 15.4 and later).** Clipboard history reads what you copy only if System Settings › Privacy & Security › Paste from Other Apps is set to Always Allow for DropNotch. Otherwise the Clipboard tab shows an Add Clipboard button after each copy, and macOS asks when you click it. If it is set to Always Deny, the tab says so and reads nothing. A change to this setting may need DropNotch to be relaunched.

**Login Items.** Only if you turn on Launch at login. macOS may ask you to approve it in System Settings › General › Login Items; Settings › General shows a button that opens it.

The prompts and denied states above are not all checked on a device yet; this section describes the intended behaviour.

## Privacy

DropNotch does not include analytics or telemetry.

Its one network request is for Spotify artwork: when a new Spotify track starts, it downloads that track's cover image over HTTPS from Spotify's image server (`i.scdn.co`), using the image address Spotify itself provides. The request carries the standard headers macOS adds (a User-Agent naming DropNotch and the macOS networking versions, your preferred languages), and Spotify's server sees your IP address; nothing else is sent, no cookies are kept, and the image is held in memory only. Music artwork comes from the Music app, with no network. To stop it, turn off Download Spotify artwork in Settings › Privacy; Spotify tracks then show Spotify's icon and nothing leaves the Mac.

Files leave the Mac only when you send them yourself with AirDrop or Share from the tray.

Now Playing reads track details from the notifications Music and Spotify broadcast on your Mac, and sends its commands straight to the player. Titles and artists are held in memory while shown, and are never saved to disk or logged.

What DropNotch stores on your Mac, all in `~/Library/Application Support/DropNotch/`:
- `Notes/note.txt`: your note, as plain text.
- `tray.json`: the tray's list, with a link (bookmark) to each file, which includes its path. `Tray/` holds copies of drops with no file behind them (for example an image dragged from Photos or Mail) and of files that couldn't be linked. Removing an item or Clear Tray deletes only these copies, never your originals.
- `clipboard.json`: only if you turn on Keep history after quitting. Text and link items only (images stay in memory), readable only by your user account and excluded from Time Machine backups. Turning the option off, turning history off, or Clear deletes it. Otherwise clipboard history is held in memory only and is cleared when DropNotch quits.

Clipboard history skips items that password managers and other apps mark as concealed or transient. Logs never contain clipboard contents, file names or track details. The open Clipboard tab shows your history to anyone who can see your screen, including in screen sharing and recordings.

## Contributing

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`). Each feature is developed on its own branch, named `feat/<name>`. Significant decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Licence

DropNotch is released under the MIT licence. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
