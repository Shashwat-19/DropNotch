#!/bin/bash
# Renders the website's pictures and clips from DropNotch's own views (DropNotchTests/SiteMedia) and encodes them into
# website/media. Every song, lyric, event and picture in them is invented. Needs XcodeGen and ffmpeg
# (brew install xcodegen ffmpeg). Run from anywhere; the frames go to build/site-media, which is gitignored.
set -euo pipefail
cd "$(dirname "$0")/.."

frames="$PWD/build/site-media"
media=website/media
rm -rf "$frames"
mkdir -p "$frames" "$media"

xcodegen generate
# TEST_RUNNER_ variables reach the test process without the prefix; without it the renderer skips itself.
TEST_RUNNER_DN_SITE_MEDIA_OUT="$frames" xcodebuild -quiet -scheme DropNotch -destination 'platform=macOS' \
    -skipPackagePluginValidation test -only-testing:DropNotchTests/SiteMediaRenderer

# Lock screen: the compact player for 2.5 s, a 0.5 s fade, then the full screen with lyrics at 15 frames a second.
ffmpeg -v error -y -loop 1 -t 2.5 -framerate 30 -i "$frames/lock-compact.png" -framerate 15 -i "$frames/lock-expanded-%03d.png" \
    -filter_complex "[0]scale=1280:-2,format=yuv420p,fps=30[a];[1]scale=1280:-2,format=yuv420p,fps=30[b];[a][b]xfade=transition=fade:duration=0.5:offset=2[v]" \
    -map "[v]" -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p -movflags +faststart -an "$media/lock-screen.mp4"
ffmpeg -v error -y -i "$frames/lock-expanded-080.png" -vf scale=1280:-2 -q:v 3 "$media/lock-screen-poster.jpg"

# Charging alert: a looping GIF, and one still frame for Reduce Motion.
ffmpeg -v error -y -framerate 15 -i "$frames/charging-%03d.png" \
    -vf "crop=760:240:220:0,scale=600:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
    -loop 0 "$media/charging-alert.gif"
ffmpeg -v error -y -i "$frames/charging-020.png" -vf "crop=760:240:220:0,scale=600:-1" -compression_level 9 "$media/charging-alert.png"

# Stills.
ffmpeg -v error -y -i "$frames/home.png" -vf scale=1600:-1 -compression_level 9 "$media/home.png"
ffmpeg -v error -y -i "$frames/notes.png" -vf "crop=1300:600:350:0" -compression_level 9 "$media/notes.png"

ls -l "$media"
