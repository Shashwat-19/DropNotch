# Phase 3 step 1: Now Playing notification and Apple Event probe

Date: 2026-10-25. Author: Claude (lead), with Shash playing music. Own research; nothing here comes from `./reference/`.

Tags: **[V]** seen in a log, a command's output, or reported by Shash; **[I]** inferred.

## Question
D24's design depends on undocumented behaviour: the names and payload keys of the players' distributed notifications, whether a background app receives them, and each player's Apple Event codes. The planner wrote all of these from memory and tagged them unverified. This probe checks them before any code is written.

## Set-up
- Mac: macOS 27.0 (Darwin 27.0.0). Music 1.7, Spotify 1.3.6.1921 [V: `mdls`]. Music used an Apple Music subscription; Spotify a free account [V: Shash].
- Probe: a throwaway Swift command-line binary in the session scratchpad, not in the repo. It runs `NSApplication` with the `.accessory` activation policy (no Dock icon, like `LSUIElement`) and is never activated [V: `active=false` on every line].
- For each notification name it registers two observers: one with `suspensionBehavior: .deliverImmediately` and one with the default. It also observes `NSWorkspace` launch and quit for the two bundle IDs.
- It prints key names and the `Player State` value only, never titles, artists or other values. It sends no Apple Events.
- Codes: `sdef` on each app bundle.
- Actions, with another app frontmost throughout [V: Shash]: launch, play, pause, play, next, previous, quit while playing; Music first, then Spotify. Music was launched again at 14:50 for listening after the test [V: Shash]. Radio and ads were not tried.

## Results

### Notifications
| | Music | Spotify |
|---|---|---|
| Name | `com.apple.Music.playerInfo` [V] | `com.spotify.client.PlaybackStateChanged` [V] |
| States seen | `Playing`, `Paused`, `Stopped` [V] | `Playing`, `Paused`, `Stopped` [V] |
| Keys with a track | `Album`, `Artist`, `Genre`, `Library PersistentID`, `Name`, `PersistentID`, `Player State`, `Total Time`; sometimes `Composer` [V] | `Album`, `Album Artist`, `Artist`, `Disc Number`, `Duration`, `Has Artwork`, `Name`, `Play Count`, `Playback Position`, `Player State`, `Popularity`, `Track ID`, `Track Number` [V] |
| State-only payloads (`Player State` key only) | On launch (`Stopped`), about 70 ms before each new track (`Stopped`), on quit while playing (`Paused`) [V] | On launch (`Stopped`), on quit (`Stopped`) [V] |
| Bursts | Pause sent `Playing` then `Paused` about 85 ms apart; play sent `Paused` then `Playing` about 25 ms apart. The last one in each burst was right [V] | One notification per action [V] |

- Delivery: the default and `.deliverImmediately` observers received every notification within 5 ms of each other, and `DistributedNotificationCenter.suspended` stayed `false` [V]. So an app that has never been active is not held back. Whether delivery is suspended after DropNotch has been active (Settings, D14) and then deactivates is untested [I].
- `userInfo` arrived in full at an unsandboxed, ad-hoc-run binary [V].
- Spotify's `Playback Position` and `Duration` could drive a progress bar later without polling the app. Music has `Total Time` but no position [V]. `Has Artwork` is a flag; no image URL [V].
- `NSWorkspace` launch and quit notifications arrived for both bundle IDs, with their pids [V].

### Apple Event codes (`sdef`)
| | Music (suite `hook`) | Spotify (suite `spfy`) |
|---|---|---|
| Play/pause | `hookPlPs` [V] | `spfyPlPs` [V] |
| Next | `hookNext` [V] | `spfyNext` [V] |
| Previous | `hookPrev` (always previous), `hookBack` (restart, then previous) [V] | `spfyPrev` [V] |
| Player state | `pPlS`: `kPSP` playing, `kPSp` paused, `kPSS` stopped [V] | same codes [V] |
| Current track, name, artist | `pTrk`, `pnam`, `pArt` [V] | same codes [V] |

## What this changes in the plan
- **State-only payloads keep the last track.** The plan's "Stopped clears the track" would blank the title on every Music track change. Only a quit clears a player (D24) [V: Shash approved].
- **Bursts are not debounced.** The latest state is shown; a possible ~90 ms flicker of the play/pause icon is a device check [V: Shash approved].
- **`.deliverImmediately` stays**: it costs one argument and covers the untested after-Settings case [V: Shash approved].
- **Music's Previous uses `hookBack`** [V: Shash].

## Not covered
- Radio and streams, Spotify ads, podcasts: an empty or odd `Name` is most likely there. Device checks (TASK.md Phase 3).
- What Spotify's `spfyPrev` does mid-track. Device check.
- Apple Events themselves: prompts, denial, pid addressing. Release-build device checks.
- One Mac, one macOS build, one version of each player.
