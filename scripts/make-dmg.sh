#!/bin/bash
# Builds a Release DropNotch.app and packs it into build/DropNotch-<version>.dmg, with an Applications shortcut,
# the licence and the third-party notices. Ad-hoc signed only: there is no Developer ID yet (README › Install).
# Needs XcodeGen and create-dmg (brew install xcodegen create-dmg). Run from anywhere.
# The window's first-launch steps are drawn by scripts/dmg-background/main.swift; keep them in step with README › Install.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
# SwiftTerm runs a build-tool plugin, so the build skips Xcode's plugin trust check (D48). Before that, make sure every
# package resolved to the commit in scripts/Package.resolved.expected: a moved tag or a new transitive package stops here.
xcodebuild -quiet -resolvePackageDependencies -scheme DropNotch -derivedDataPath build/DerivedData
grep -E '"(identity|revision)"' DropNotch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    | sed -E 's/.*: "([^"]+)".*/\1/' | paste - - | diff -u scripts/Package.resolved.expected - \
    || { echo "Resolved packages differ from scripts/Package.resolved.expected." >&2; exit 1; }
xcodebuild -quiet -scheme DropNotch -configuration Release -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile clean build

app=build/DerivedData/Build/Products/Release/DropNotch.app
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
dmg="build/DropNotch-$version.dmg"
# A mounted volume with the same name makes Finder's alias to the window background point at it, and the new DMG then
# opens with no background (seen 2026-11-01).
if [ -e "/Volumes/DropNotch $version" ]; then
    echo "Eject /Volumes/DropNotch $version first." >&2
    exit 1
fi
staging=$(mktemp -d)

# The window's background with the first-launch steps (scripts/dmg-background), 1x and 2x in one TIFF so Finder picks
# the sharp one on Retina screens. Kept out of the staging folder: create-dmg copies it into the hidden .background.
art=$(mktemp -d)
trap 'rm -rf "$staging" "$art"' EXIT
swiftc -o "$art/background" DropNotch/Notch/NotchShape.swift scripts/dmg-background/main.swift
"$art/background" "$art"
tiffutil -cathidpicheck "$art/background.png" "$art/background@2x.png" -out "$art/background.tiff" 2>/dev/null

# ditto keeps the app's signature and extended attributes intact.
ditto "$app" "$staging/DropNotch.app"
cp LICENSE THIRD_PARTY_NOTICES.md "$staging/"
rm -f "$dmg"
# Icon positions are the marks in scripts/dmg-background/main.swift. The window is the background (640 × 510)
# plus Finder's title bar, about 32 pt.
create-dmg --volname "DropNotch $version" --background "$art/background.tiff" --window-size 640 542 \
    --icon-size 80 --text-size 12 \
    --icon DropNotch.app 170 150 --app-drop-link 470 150 \
    --icon LICENSE 240 445 --icon THIRD_PARTY_NOTICES.md 400 445 \
    --hide-extension DropNotch.app --hide-extension THIRD_PARTY_NOTICES.md \
    "$dmg" "$staging"
# Published with the release, so a download can be checked: the DMG has no Developer ID signature (README › Install).
(cd build && shasum -a 256 "$(basename "$dmg")" | tee "$(basename "$dmg").sha256")
