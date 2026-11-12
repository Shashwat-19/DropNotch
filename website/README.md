# DropNotch website

One static page, `index.html`, with no build step and no dependencies. Its job is to find out whether strangers want DropNotch, not to look finished. The launch plan, headline candidates and kill threshold are in [LAUNCH.md](LAUNCH.md).

## Deploy

Vercel project `dropnotch`, connected to this repository with **Root Directory** `website` and no framework or build command. A push that changes `website/` deploys it: `main` goes to production, and other branches get preview URLs. `.vercelignore` keeps the notes and the download log off the site.

## Measure

| What | Where | Notes |
|---|---|---|
| Visitors, referrers, countries | Vercel › dropnotch › Analytics | Turn on Web Analytics once in the dashboard. Until then, `/_vercel/insights/script.js` returns 404 and nothing is counted. Cookieless. |
| Download and copy clicks | Same, under Events | `data-track` on the buttons. Custom events need a Vercel Pro plan; on Hobby they're dropped. Unverified on this account. |
| DMG downloads | `./downloads.sh` | Appends one row per release to `downloads.csv`. Run it once a day. Counts include `brew install` (the cask fetches the same asset), repeat downloads and bots. Baseline on 2026-11-11: v0.2.0 = 2, v0.1.0 = 0. |
| What people want | [GitHub Issues](https://github.com/Shashwat-19/DropNotch/issues) | Linked in the nav, after install and in the footer. |

## Each release

The DMG links name the version. After a release, replace `0.2.0` in `index.html` (two download buttons, the SHA-256 link and the meta line), and update the size in the meta line from `gh api repos/Shashwat-19/DropNotch/releases/latest --jq '.assets[0].size'`. RELEASING.md step 10.

## Adding the feature clips

Each bento tile has a `<div class="clip">` placeholder whose `data-claim` says what to record. For each one:

1. Record the notch area only, about 2:1, 4–8 s, no sound. Export H.264 `.mp4` under 2 MB to `website/clips/<name>.mp4`.
2. Replace the placeholder's text with `<video src="clips/<name>.mp4" autoplay muted loop playsinline aria-label="<what happens in the clip>"></video>`, and change its `data-claim` to `verified: recorded from v0.2.0`.
3. Before shipping the first clip, add a few lines that pause the videos when `prefers-reduced-motion: reduce` matches; looping video is the motion that setting asks us to stop.

## Claims ledger

Every claim on the page carries `data-claim`. Open the page with `?claims` to outline them: green means verified from the repository, amber is a placeholder for you to fill in.

| Claim on the page | Status | Source |
|---|---|---|
| Notch illustration (Now Playing and Calendar cards) | Verified, labelled "Illustration, not a screenshot" | README Features; demo timings match D18 (0.12 s open) and the 0.1 s exit debounce |
| Free and open source, MIT | Verified | `LICENSE` |
| macOS 14 or later | Verified | `project.yml` `deploymentTarget: macOS: "14.0"` |
| Headline "Music, files, clipboard and a terminal, one hover from your notch." | **Placeholder** | Candidate A in LAUNCH.md; choose with the evidence |
| Opens on hover or ⌃⌥N | Verified | `DropNotch/App/AppDelegate.swift` (`toggleNotch`, `.n` with control + option); README Usage |
| Download link, version 0.2.0, 7.5 MB | Verified | GitHub API, release v0.2.0, `DropNotch-0.2.0.dmg`, 7,468,146 bytes |
| Not yet notarised; extra first-launch step | Verified | CHANGELOG 0.2.0 Known issues; README Install |
| `brew install --cask shashwat-19/tap/dropnotch` | Verified | Shashwat-19/homebrew-tap `Casks/dropnotch.rb` (version 0.2.0, sha256 matches TASK.md); D50 |
| Play, pause, skip, seek in Music and Spotify; artwork, times | Verified | README Features; CHANGELOG 0.1.0 and 0.2.0 |
| Today's events, read only; optional battery ring | Verified | CHANGELOG 0.2.0 Calendar and Battery cards |
| Tray: drop, drag out, AirDrop; files stay put | Verified | CHANGELOG 0.1.0; `FileTrayExpandedView.swift` (`canAirDrop`) |
| Clipboard: last 25 items, off by default, password-manager entries skipped | Verified | `ClipboardModule.swift` (`limit = 25`, concealed types); README Privacy |
| Terminal: login shell, off by default, never starts on hover, keeps running | Verified | CHANGELOG 0.2.0 Terminal tab |
| One note, saved as you type | Verified | CHANGELOG 0.1.0 Notes |
| ⌘1, ⌘2 switch tabs; Esc closes; keyboard access; VoiceOver labels | Verified | README Usage and Features |
| Not built yet: Stats, timer, live lyrics; signed builds and updates for 1.0 | Verified | README Roadmap |
| Six feature clips | **Placeholder** | Not recorded yet; README's own TODO says no screenshots exist |
| FAQ: free, no account | Verified | `LICENSE`; README Privacy |
| FAQ: why macOS blocks it; Open Anyway; signing planned for 1.0 | Verified | README Install and Roadmap |
| FAQ: Macs, notch or pill, Apple silicon only tested | Verified | README Requirements |
| FAQ: no analytics; only network request is Spotify artwork from i.scdn.co; can be turned off | Verified | README Privacy; `Services/ArtworkDownloader.swift`; CHANGELOG 0.1.0 |
| FAQ: permissions and when they're asked | Verified | README Privacy and permissions; CHANGELOG 0.1.0 and 0.2.0 |
| FAQ: Apple Music and Spotify only | Verified | README Features; FEATURE_MATRIX (other players: Later) |
| FAQ: terminal uses DropNotch's permissions; Settings shows them first | Verified | CHANGELOG 0.2.0; README Privacy |
| FAQ: no auto-updates; `brew upgrade`; uninstall | Verified | CHANGELOG 0.2.0 Known issues; README Install; CHANGELOG 0.1.0 (menu-bar Quit) |
| Made by Shashwat | Verified | `LICENSE` copyright line |
| Site uses cookieless Vercel Web Analytics; app counts nothing | Verified | Vercel Web Analytics docs; README Privacy |
