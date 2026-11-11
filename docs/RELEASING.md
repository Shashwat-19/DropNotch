# Releasing

For maintainers. Run everything from the repository root. The commands show 0.1.0; change the version throughout for a later release. Nothing here is run by the build or by CI.

Before you start: the device checks in TASK.md's Release checklist are done, `xcodebuild -scheme DropNotch -destination 'platform=macOS' -skipPackagePluginValidation build test` passes, and CHANGELOG.md has the version's section.

1. **README commit.** Update README.md (download link, install steps, checksum command) and CHANGELOG.md on the `release/v0.1.0` branch, then commit with `docs:`. Write `build/notes-final.md` from the CHANGELOG section: highlights, three install lines, known limitations, and the line `SHA-256 (DropNotch-0.1.0.dmg): <sha256>`. `build/` is gitignored, so this file is not committed.
2. **Merge to main and push.**
   ```sh
   git switch main && git merge --no-ff release/v0.1.0 && git push origin main
   ```
3. **Build the DMG from main.** `git status --short` must print nothing. Eject any mounted "DropNotch 0.1.0" volume (the script refuses to build while one is mounted).
   ```sh
   ./scripts/make-dmg.sh
   (cd build && shasum -a 256 -c DropNotch-0.1.0.dmg.sha256)
   ```
   The hash changes with every build, so the DMG you upload must come from the commit you tag.
4. **Tag and push the tag.**
   ```sh
   git tag -a v0.1.0 -m "DropNotch 0.1.0" && git push origin v0.1.0
   ```
5. **Checksum into the notes.** This replaces whatever follows `SHA-256 (DropNotch-0.1.0.dmg): ` in place, so it can be re-run after a rebuild.
   ```sh
   sed -i '' -E "s|^(SHA-256 \(DropNotch-0\.1\.0\.dmg\): ).*$|\1$(cut -d' ' -f1 build/DropNotch-0.1.0.dmg.sha256)|" build/notes-final.md
   ```
6. **Create the pre-release.** `--verify-tag` stops it if step 4's tag isn't on the remote. A pre-release never counts as "latest", so the README links to the tag page, not `/releases/latest`.
   ```sh
   gh release create v0.1.0 build/DropNotch-0.1.0.dmg build/DropNotch-0.1.0.dmg.sha256 \
     --verify-tag --prerelease --title "DropNotch 0.1.0" --notes-file build/notes-final.md
   ```
7. **Verify while the repository is still private.** Only you can see it now. Open the release page and check: marked Pre-release, both assets attached, the checksum line has a real hash. Open the README on `main` and click the Download badge and the release-page link. Download the DMG from the release page and run the checksum command from the README in that folder.
8. **Make it public.**
   ```sh
   gh repo edit Shashwat-19/DropNotch --visibility public --accept-visibility-change-consequences \
     --description "Turns the MacBook notch into a productivity surface"
   ```
   This is hard to undo: the repository, its history and the release become visible and may be cached or forked.
9. **Update the Homebrew cask.** After every release, bump `version` and `sha256` in `Casks/dropnotch.rb` in [Shashwat-19/homebrew-tap](https://github.com/Shashwat-19/homebrew-tap). Take the hash from the release's `.sha256` asset. Copy the edited cask into the tapped copy (`$(brew --repo shashwat-19/tap)/Casks/`) or push and `brew update` first, then check:
   ```sh
   brew livecheck --cask shashwat-19/tap/dropnotch   # prints 0.1.0 ==> 0.1.0 when the cask matches the newest release
   brew style shashwat-19/tap && brew audit --cask shashwat-19/tap/dropnotch
   ```
   Commit and push the tap. `brew audit --cask --new` also fails because the app isn't notarised and the repository is below Homebrew's notability threshold (D50); those rules apply only to the official homebrew/cask.
