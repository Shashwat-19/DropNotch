# Phase 2 step a: clipboard-access probe and Apple-docs check

Date: 2026-10-24. Author: Claude (lead), with Shash watching the screen. Own research; nothing here comes from `./reference/`.

Tags: **[V]** seen in a log, a command's output, Apple documentation, or reported by Shash; **[I]** inferred.

## 1. Clipboard-access probe

### Question
From macOS 15.4, Apple says the general pasteboard "asks upon programmatic access" by default [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]. D7 needs to know whether a background app that watches `changeCount` and reads new items will make macOS show an alert, and which kind of read triggers it.

### Set-up
- Mac: macOS 27.0.1 (build 26A434) [V: probe log].
- Probe: a throwaway Swift app built in the session scratchpad, not in the repo. Bundle ID `com.shashwat.ClipboardProbe`, agent app (`LSUIElement`), ad-hoc signed with the hardened runtime (`flags=0x10002(adhoc,runtime)`) [V: `codesign -dvvv`]. App Nap disabled for the run so the 0.5 s timer isn't throttled.
- Launch: `/usr/bin/open -n ClipboardProbe.app`. Its parent was `launchd` (PPID 1) and LaunchServices registered it under its own bundle ID, so macOS treated it as its own app, not as part of Terminal or iTerm2 [V: `ps`, `lsappinfo`].
- Other apps: no running app's name suggested clipboard, notch, paste or island. Canopy (a notch app) was running at first; Shash quit it before the run [V: `lsappinfo`, before and after].
- Copies: six strings ("dropnotch probe test 1" to 6) placed on the clipboard with `pbcopy`, 4 s apart, 18:12:24 to 18:12:44 local time [V: command output].
- What the probe read, by copy number: 1–2 `changeCount` only; 3 the `types` list; 4 `detectedPatterns(for:)`, which Apple documents as not notifying the user; 5–6 the string itself. It logged lengths and timings only, never content.

### Results
| Copy | Read | Result | Time taken | `accessBehavior` |
|---|---|---|---|---|
| — | at launch | — | — | `alwaysAllow` |
| 1 | `changeCount` | 200 | — | — |
| 2 | `changeCount` | 201 | — | — |
| 3 | `types` | 2 types, no concealed marker | 0.02 s | `alwaysAllow` |
| 4 | `detectedPatterns(for:)` (web URL, number) | 0 matched | 0.01 s | `alwaysAllow` |
| 5 | string | 23 characters | 0.00 s | `alwaysAllow` |
| 6 | string | 23 characters | 0.00 s | `alwaysAllow` |

All six copies were seen; the probe exited normally [V: probe log]. **No alert appeared on any copy** [V: reported by Shash]. System Settings › Privacy & Security had no paste or clipboard section to inspect [V: reported by Shash].

Earlier attempts don't count: in the first run only one of Shash's TextEdit copies reached the clipboard (the system `changeCount` stayed at 178) [V: log and a counter-only check], so that run was discarded.

### What this does and doesn't show
- On this Mac, today, an ad-hoc-signed background app reported `alwaysAllow` and could read clipboard text silently [V].
- It does **not** show what happens when the setting is "ask", which Apple documents as the default. We couldn't put the probe into "ask": there was no setting to change, and we didn't find a documented way to reset it [I]. So the original question — do `changeCount` or `types` reads count as access under "ask"? — is still open.
- Why it was `alwaysAllow` is unknown [I]. Possibilities: a different default on macOS 27, a setting on this Mac, the copy source being a command-line tool rather than an app, or how macOS treats apps without a Team ID. None is confirmed.
- One Mac, one macOS build, one signing type. A Developer ID build on another Mac may behave differently [I].

## 2. Apple-docs check of inferred claims

All [I]-tagged Apple-API claims in ARCHITECTURE.md, RISKS.md, FEATURE_MATRIX.md and DECISIONS.md were checked against developer.apple.com (or support.apple.com where the developer docs don't cover it). 34 corrections were applied (commit 4862f9f). The ones that change plans:
- **Clipboard:** "ask on programmatic access" from macOS 15.4; Always Deny fails silently; `detectedPatterns(for:)` doesn't notify but only reports matches; Apple defines no concealed or transient type (the markers are the nspasteboard.org convention) [V, URLs in RISKS.md §2].
- **Screen capture:** Apple says not to use `sharingType` to hide content [V].
- **Logging:** `os.Logger` redacts strings by default but not numbers [V].
- **Displays:** a display ID usually stays the same only until restart [V].
- **Remaining [I] tags (69):** these are about Atoll, Canopy or MediaRemote, design reasoning, or things only a device can confirm. The device checks are listed in TASK.md step i.

## 3. What this means for D7

**Recommendation: clipboard history stays in the MVP, with three design changes.** It doesn't need to move to v0.2: the reads work, and no alert appeared here. But Apple documents "ask" as the default, so the design has to handle it rather than rely on this Mac's `alwaysAllow`.

1. **Check `accessBehavior` when the user turns clipboard history on** (macOS 15.4+, behind `#available`; the target is 14.0).
   - `alwaysAllow`: start watching.
   - `ask` or `default`: show our own explanation first ("macOS may ask whether DropNotch can read the clipboard"), then start.
   - `alwaysDeny`: don't start; show a "blocked in System Settings" state instead of an empty history.
2. **Read in the cheapest order:** `changeCount` on the timer, then `types` only when it changes, skip concealed and transient items, and only then read the content. This limits how often content is read, if "ask" counts each read [I].
3. **Re-check `accessBehavior` on each read** and stop watching if it becomes `alwaysDeny`, because Apple says denied access fails silently [V].

Still to confirm on a device under "ask" (TASK.md step i): whether reading `changeCount` or `types` alone triggers the alert, and whether `changeCount` still works under Always Deny.
