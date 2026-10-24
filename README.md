# DropNotch

DropNotch is an open-source macOS utility that turns the MacBook notch into a productivity surface. The planned features are now-playing controls, a file tray with AirDrop, clipboard history and quick notes. The panel is meant to expand on hover or a hotkey and stay minimal otherwise. None of these features works yet.

## Status

Pre-alpha. The project is at the foundation stage and has no usable features. The plans are in:

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

## Privacy

DropNotch does not include analytics or telemetry.

## Contributing

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`). Each feature is developed on its own branch, named `feat/<name>`. Significant decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Licence

DropNotch is released under the MIT licence. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
