# Phase 3 branch 2 step 0: progress, artwork and favourite probe

Date: 2026-10-25. Author: Claude (lead), with Shash playing music. Own research; nothing here comes from `./reference/`.

Tags: **[V]** seen in a log, a command's output, or reported by Shash; **[I]** inferred.

## Question
D26 needs the units of every position and duration, whether seeks send notifications, how the track ids line up, what Music's artwork read returns, what Spotify's artwork URL points at, and whether Music's `favorited` property can be trusted. D25 needs the artwork host and response sizes. Decision 3 of the plan needs to know whether a system-driven view can animate a thin bar without our own redraw.

## Set-up
- Mac: macOS 27.0. Music 1.7 with an Apple Music subscription, Spotify 1.3.6.1921 on a free account [V: branch 1 probe].
- Probe: a throwaway Swift binary in the session scratchpad, not in the repo. A background listener (accessory activation policy) logged each player notification and, after it, read state by Apple Event: Music on every notification; Spotify only when its track id changed. It built its events the same way as `AppleEventSender`.
- Output: numbers, types, byte counts, magic bytes, error codes, hosts and match booleans only. Never titles, artists, ids, URL paths or image bytes [V: log].
- Automation: the probe ran under iTerm, which macOS asked about once per player; Shash allowed both [V]. Shash turns them off after this branch.
- Seek writes were sent by one-off probe runs while the listener ran. The favourite write was not sent (see Results).
- The bar test ran four variants in a small window, measured with `top` (CPU, idle wake-ups) and two window captures 10 s apart.

## Results

### Units
| Source | Music | Spotify |
|---|---|---|
| Notification duration | `Total Time`, Int64, **milliseconds** [V] | `Duration`, Int64, **milliseconds** [V] |
| Notification position | none [V] | `Playback Position`, Double, **seconds** [V] |
| Apple Event `pPos` (player position) | Float32, seconds [V] | Double, seconds [V] |
| Apple Event `pDur` (track duration) | Float32, seconds [V] | Int32, **milliseconds**; the dictionary says seconds [V] |

- Music's notification once gave a rounded `Total Time` at the start of a track (214000, then 214716 a minute later), against 214.673 s by Apple Event [V].
- Spotify's notification at launch said position 0 while the Apple Event read said 19.66 s, and the next Play notification said 19.68 s [V]. The launch notification's position is not reliable.

### Track ids
- Music: the notification's `PersistentID` (signed Int64) equals `persistent ID` (`pPIS`, 16 hex characters) when written as the unsigned bit pattern in upper-case hex (`%016llX`). Every read made while the track was current matched [V].
- Spotify: `Track ID` equals the track's `id` (`ID  `) [V].

### Between Music tracks
Music's state-only `Stopped` arrives just before the next track. Reads at that moment fail with -1728 (no such object) for duration, favourite and id, and `pPos` comes back as a non-number descriptor [V].

### Read cost
Four reads take 50–70 ms in total for either player; once 367 ms [V]. Music still sends bursts (`Playing` then `Paused` within 20–170 ms) [V].

### Music artwork
`raw data` (`pRaw`, type `tdta`) and `data` (`pPCT`, type `JPEG`) of `artwork 1 of current track` returned identical bytes: JPEG (`FFD8FFE0`), 515,923 and 529,196 bytes, 15–16 ms each [V]. One of the two tracks was a catalogue ("shared") track [V: class read by osascript]. Radio and tracks without artwork were not seen.

### Spotify artwork
`artwork url` (`aUrl`): scheme `https`, host `i.scdn.co` for both tracks [V]. One GET each with an ephemeral session and redirects refused: status 200, `image/jpeg`, 60,941 and 38,529 bytes, `FFD8FFE0`, no redirect, 158 and 88 ms [V].

### Seeks
- By Apple Event (`core/setd` on `pPos`): worked on both players (status 0; the position then read 30.0) and **sent no notification** on either [V]. Both players were paused; a seek during playback was not tested.
- In the player's own window: inconclusive. Each player sent one `Playing` notification whose position had jumped (Music 72 → 6.8 s, Spotify 87.6 → 4.1 s), but each came with a change of state, so the drag and the play can't be told apart [V: log; cause I].

### Music favourite
`favorited` (`pLov`) read **true** for every track, including the one left playing (class "shared track"). Music's own ⋯ menu for that track offered "Favourite", so it was **not** a favourite [V: Shash]. The property misreports, at least for catalogue tracks. The toggle-and-restore write was not sent, so the library was not changed.

### Bar animation (plan decision 3)
| Variant | App CPU | Idle wake-ups | Result |
|---|---|---|---|
| a. `ProgressView(timerInterval:)` | ~12 % throughout [V] | a few per second [V] | Smooth, but the system style can't be made thin |
| b. The same with a custom `ProgressViewStyle` | 0 % [V] | 0 [V] | Doesn't move: the style's body ran once [V] |
| c. `TimelineView(.periodic(by: 1))` | 0.1–0.6 % [V] | about 1/s | 1 s steps |
| d. Core Animation `CABasicAnimation` on a layer | 0–0.2 % [V] | 0 [V] | Moved from about 4 % to 25 % between captures [V]; smooth by construction [I] |

- d's cost inside WindowServer could not be measured: WindowServer used 42–48 % with or without the window [V].
- d scaled the layer; the rounded ends squash at small widths [V: capture]. Animate the width instead.

## What this changes in the plan (Shash, 2026-10-25)
- Favourite is dropped from this branch (D26).
- The bar is a Core Animation layer animating its width (d), with no app timer.
- The position is read each time the notch opens, for both players.
- Spotify reads happen when a track id is first seen (which covers launch); Music reads on every state notification.
- Caps: Music artwork 10 MB; Spotify artwork from `i.scdn.co` only, 2 MB.
- -1728 and non-number positions are treated as unknown.

## Not covered
Radio, tracks without artwork, catalogue versus library artwork on more tracks, Spotify ads and podcasts, seeks during playback, `favorited` on library (non-catalogue) tracks. One Mac, one macOS build, one version of each player.
