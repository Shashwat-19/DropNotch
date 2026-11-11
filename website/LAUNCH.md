# Launch test

The site exists to answer one question: do strangers want DropNotch? This file holds what the product is today, three candidate headlines, the evidence that chooses between them, a 7-day plan and the kill threshold. Fill in the Results section on day 7.

## What DropNotch is today (v0.2.0, released 2026-11-10)

**Ships and works** (checked against the code, the CHANGELOG and the release assets):

- A notch panel that opens on hover (0.12 s delay) or ⌃⌥N, in Standard or Large sizes; a pill on Macs without a notch.
- Home tab: Now Playing for Apple Music and Spotify (play, pause, skip, seek, artwork), a read-only Calendar card and an optional Battery card.
- Notes (one plain-text note), a file tray with drag-out and AirDrop, clipboard history (25 items, off by default) and a terminal tab (off by default).
- Settings: modules on/off and order, launch at login, hotkey, display choice, privacy options.
- Install from the DMG or `brew install --cask shashwat-19/tap/dropnotch`.

**Not done, or planned only:**

- Not signed with a Developer ID and not notarised, so every user must click Open Anyway. Planned for 1.0, along with Sparkle automatic updates.
- Stats, timer and live lyrics: planned (README roadmap), not started.
- Players other than Music and Spotify, more than one display, a real audio waveform (the compact one is decorative): Later.
- AirPods battery: under evaluation, no stable public API.
- Quick commands: built on a branch, set aside unmerged.
- Not in the official homebrew/cask: fails notarisation and notability (D50).
- Untested: Intel Macs; VoiceOver on Home; energy use; parts of Spotify (CHANGELOG 0.2.0 Known issues).
- No screenshots or clips exist yet. That's the biggest gap on the page.

## Headline candidates

Each one is built only on shipped features. None claims to be first, only, fastest or lightest; nothing in the repository supports that.

| | Headline | Rests on | Risk |
|---|---|---|---|
| **A** (on the page now) | Music, files, clipboard and a terminal, one hover from your notch. | Home, Tray, Clipboard and Terminal tabs | Breadth is what Boring Notch and Atoll already offer; it may not give anyone a reason to switch. |
| **B** | Drop files on your notch. Drag them out, or AirDrop them. | Tray + AirDrop (0.1.0) | NotchDrop's whole pitch, and Boring Notch has a shelf. Wins only if people report pain with those. |
| **C** | A real terminal in your MacBook notch, one keystroke away. | Terminal tab + ⌃⌥N (0.2.0) | Could be a small niche. Needs evidence that people asked for it. |

## Evidence to collect before day 1 (about 2 hours)

The question for each candidate: do distinct people ask for it, or complain that incumbents do it badly? Count people, not 👍; one person with five comments is one signal.

**1. Feature requests and complaints in the three incumbent repos.** Repos: `TheBoredTeam/boring.notch`, `Ebullioscopic/Atoll`, `Lakr233/NotchDrop` (slugs checked 2026-11-11). Run each keyword against each repo:

```sh
for repo in TheBoredTeam/boring.notch Ebullioscopic/Atoll Lakr233/NotchDrop; do
  for kw in terminal shell clipboard shelf tray airdrop drag file; do
    gh api -X GET search/issues -f q="repo:$repo is:issue in:title $kw" -f per_page=100 \
      --jq "\"$repo $kw total=\(.total_count)\", (.items[] | \"  \(.reactions[\"+1\"])👍 \(.state) \(.title) \(.html_url)\")"
  done
done > evidence-issues.txt
```

Read the hits and tally, per candidate:

| Signal | Supports |
|---|---|
| Requests for a terminal, shell or command runner | C |
| Bugs or complaints about the shelf/tray: drag-out failing, AirDrop missing, files lost | B |
| Requests for clipboard history inside the notch | A |
| "Too many features", "bloated", "I only use the music part" | against A |
| Requests that DropNotch can't meet (other players, multiple displays, lock screen) | Note them. They're the real competition, not a headline. |

Also note, for context rather than headline choice: whether each incumbent is actively maintained (Boring Notch and Atoll were pushed to on 2026-11-11, NotchDrop last on 2026-05-18), and Gatekeeper or notarisation complaints (DropNotch has the same weakness).

**2. r/macapps.** Search `notch` in r/macapps, sorted Top, Past year: `https://www.reddit.com/r/macapps/search/?q=notch&restrict_sr=1&sort=top&t=year`. For the top 20 threads, record:

- Which feature each commenter names as the reason they use, or would use, a notch app: music, files, clipboard, calendar, terminal, other.
- Rejections: "notch apps are gimmicks", "I already use Dropover, Yoink or Maccy". These say the feature is solved elsewhere.
- For launch posts of other notch apps: upvotes, comment count and the top comment's tone. That's your baseline for what a new notch app gets.
- Read the subreddit's self-promotion rules before posting.

**Decision rule.** Choose the candidate with the most distinct people asking for it or complaining about it, minus those who say it's already solved. If none clearly leads (less than about 2× the next one), keep A: it's true, broad, and the download numbers will speak. Record the tally below before day 1 and don't change the headline mid-test.

## 7-day plan

Day 0 is preparation and isn't counted. Days 1–7 are the measured window.

| Day | Do | Log |
|---|---|---|
| 0 | Record the 6 clips and replace the placeholders (README › Adding the feature clips). Turn on Web Analytics. Collect the evidence and set the headline. Run `./downloads.sh` for the baseline. Draft the r/macapps post: headline, one clip, link to the site, and up front: free, MIT, not notarised yet. | Baseline downloads |
| 1 (Tue–Thu) | Post to r/macapps. Reply to every comment the same day. | Visitors, downloads |
| 2 | Show HN: "Show HN: DropNotch – \<headline\>", US morning. Link the site; put the repository in the first comment. | Visitors, downloads, referrers |
| 3 | Fix whatever first-run friction people reported. Answer every issue within 24 h. Post one clip on the social network where you have followers. | Issues opened by others |
| 4 | Mid-point read. Under 100 visitors so far means distribution, not the product: add one channel that matches the headline (for C, a terminal community; for B, a macOS productivity one). | Visitors, conversion |
| 5 | Open a PR adding DropNotch to `serhii-londar/open-source-mac-os-apps`. If a fix is ready, ship 0.2.1 (RELEASING.md, including the cask and website steps). | |
| 6 | In the existing threads, ask people who tried it what they'd change or why they uninstalled. Nothing new to launch. | Replies |
| 7 | Final read against the threshold below. Write the result here. | Everything |

Run `./downloads.sh` every day. Downloads in the CSV are cumulative; subtract the day-0 baseline and your own downloads.

## Kill threshold

Measured over days 1–7. These numbers are my starting proposal, not an industry benchmark. Change them before day 1 if you disagree, never after.

- **The test counts only if the site gets at least 300 unique visitors** (Vercel Analytics). Fewer means the post didn't reach people. That's a distribution result, not a product verdict: run one more week with two new channels. If that week also stays under 300, nobody clicking is itself the answer, so stop.
- **Kill** if the test counts AND new DMG downloads are under 10% of visitors (under 30 at 300) AND fewer than 3 people other than you open an issue or comment asking for something.
- **Continue** if downloads reach 10% of visitors, or 3 or more strangers ask for something. Their requests set the next release.
- **Kill means:** stop launch work and building for strangers. Keep DropNotch as your own tool and the repository public. Don't spend $99 a year on a Developer ID for it.

## Results (fill in on day 7)

| | Value |
|---|---|
| Headline used | |
| Evidence tally (A / B / C) | |
| Unique visitors | |
| New DMG downloads (CSV minus baseline) | |
| Conversion | |
| Issues or requests from strangers | |
| Top referrers | |
| Verdict | |
