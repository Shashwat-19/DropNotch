#!/bin/bash
# Builds a Release DropNotch.app and packs it into build/DropNotch-<version>.dmg, with an Applications shortcut,
# the licence and the third-party notices. Ad-hoc signed only: there is no Developer ID yet (README › Install).
# Needs XcodeGen and create-dmg (brew install xcodegen create-dmg). Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -quiet -scheme DropNotch -configuration Release -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData clean build

app=build/DerivedData/Build/Products/Release/DropNotch.app
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
dmg="build/DropNotch-$version.dmg"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

# ditto keeps the app's signature and extended attributes intact.
ditto "$app" "$staging/DropNotch.app"
cp LICENSE THIRD_PARTY_NOTICES.md "$staging/"
rm -f "$dmg"
create-dmg --volname "DropNotch $version" --window-size 540 400 --icon-size 96 \
    --icon DropNotch.app 140 150 --app-drop-link 400 150 \
    --icon LICENSE 140 300 --icon THIRD_PARTY_NOTICES.md 400 300 \
    "$dmg" "$staging"
echo "$dmg"
