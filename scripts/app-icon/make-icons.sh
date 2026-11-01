#!/bin/zsh
# Regenerates DropNotch/Assets.xcassets/AppIcon.appiconset from main.swift (D38).
set -euo pipefail
cd "${0:A:h}/../.."
out=DropNotch/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swiftc -o "$tmp/icon" DropNotch/Notch/NotchShape.swift scripts/app-icon/main.swift
"$tmp/icon" "$tmp/icon_1024.png"
mkdir -p "$out"
for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size "$tmp/icon_1024.png" --out "$out/icon_$size.png" >/dev/null
done
