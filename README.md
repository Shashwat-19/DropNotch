# DropNotch

DropNotch is an open-source macOS utility that turns the MacBook notch into a productivity surface. The notch opens when you hover over it and stays minimal otherwise.

What works today:
- Now Playing for Apple Music and Spotify: the open notch shows the current title and artist, with artwork, a progress bar you can seek, and play/pause, next and previous controls.
- While music plays, the closed notch widens a little to show the artwork on the left and small animated bars on the right.

Planned, not built yet: a hotkey to open the notch, a file tray with AirDrop, clipboard history and quick notes.

## Status

Pre-alpha. Some checks are still outstanding, including how the Automation permission behaves (see [Permissions](#permissions)). The plans are in:

- [docs/FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/DECISIONS.md](docs/DECISIONS.md)

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

The prompt and the denied state are not yet checked on a device; this section describes the intended behaviour.

## Privacy

DropNotch does not include analytics or telemetry.

Its one network request is for Spotify artwork: when a new Spotify track starts, it downloads that track's cover image over HTTPS from Spotify's image server (`i.scdn.co`), using the image address Spotify itself provides. The request carries the standard headers macOS adds (a User-Agent naming DropNotch and the macOS networking versions, your preferred languages), and Spotify's server sees your IP address; nothing else is sent, no cookies are kept, and the image is held in memory only. Music artwork comes from the Music app, with no network.

Now Playing reads track details from the notifications Music and Spotify broadcast on your Mac, and sends its commands straight to the player. Titles and artists are held in memory while shown, and are never saved to disk or logged.

## Contributing

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`). Each feature is developed on its own branch, named `feat/<name>`. Significant decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Licence

DropNotch is released under the MIT licence. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
