#!/bin/sh
# Appends today's DMG download count per release to downloads.csv (date,tag,downloads).
# Counts include Homebrew installs: the cask downloads the same release asset.
# Needs the GitHub CLI (gh), signed in. Run once a day during the launch week.
set -eu
cd "$(dirname "$0")"
[ -f downloads.csv ] || echo "date,tag,downloads" > downloads.csv
gh api repos/Shashwat-19/DropNotch/releases --jq '
  (now | strftime("%Y-%m-%d")) as $d
  | .[] | .tag_name as $t
  | .assets[] | select(.name | endswith(".dmg"))
  | "\($d),\($t),\(.download_count)"' | tee -a downloads.csv
