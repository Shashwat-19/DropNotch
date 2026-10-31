# Phase 2 step a: clipboard-access probe and Apple-docs check

Date: 2026-10-24. Author: Claude (lead), with Shash watching the screen. Own research; nothing here comes from `./reference/`.

Tags: **[V]** seen in a log, a command's output, Apple documentation, or reported by Shash; **[I]** inferred.

## 1. Clipboard-access probe

### Question
From macOS 15.4, Apple says the general pasteboard's default is "to ask upon programmatic access" [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]. D7 needs to know whether a background app that watches `changeCount` and reads new items will make macOS show an alert, and which kind of read triggers it.

### Set-up
- Mac: macOS 27.0.1 (build 26A434) [V: probe log].
- Probe: a throwaway Swift app built in the session scratchpad, not in the repo. Bundle ID `com.shashwat.ClipboardProbe`, agent app (`LSUIElement`), ad-hoc signed with the hardened runtime (`flags=0x10002(adhoc,runtime)`) [V: `codesign -dvvv`]. App Nap disabled for the run (a `beginActivity` call in the probe source) so the 0.5 s timer isn't throttled.
- Launch: `/usr/bin/open -n ClipboardProbe.app`. Its parent was `launchd` (PPID 1) and LaunchServices registered it under its own bundle ID [V: `ps`, `lsappinfo`]; how macOS attributes its pasteboard reads is [I].
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

All six copies were seen; the log ends "done after 6 copies" [V: probe log]. **No alert appeared on any copy** [V: reported by Shash]. System Settings › Privacy & Security had no paste or clipboard section to inspect [V: reported by Shash].

Earlier attempts don't count: in the first run (copies made by hand in TextEdit [V: reported by Shash]) the system `changeCount` stayed at 178 after the first copy [V: log and a counter-only check], so that run was discarded.

### What this does and doesn't show
- On this Mac, today, an ad-hoc-signed background app reported `alwaysAllow` and read clipboard text with no alert reported [V].
- It does **not** show what happens when the setting is "ask", which Apple documents as the default. System Settings shows the per-app setting only for apps that have already triggered a pasteboard alert [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]. This probe never triggered one, so there was no setting to switch to "ask". So the original question — do `changeCount` or `types` reads count as access under "ask"? — is still open.
- Apple documents that an app which has never triggered an alert reports `default` [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum], so the observed `alwaysAllow` is unexplained, not just unknown [I]. Possibilities: a different default on macOS 27, a setting on this Mac, the copy source being a command-line tool rather than an app, or how macOS treats apps without a Team ID. None is confirmed.
- One Mac, one macOS build, one signing type. A Developer ID build on another Mac may behave differently [I].

## 2. Apple-docs check of inferred claims

The [I]-tagged Apple-API claims in ARCHITECTURE.md, RISKS.md, FEATURE_MATRIX.md and DECISIONS.md were checked against developer.apple.com (or support.apple.com where the developer docs don't cover it), and about 30 lines were corrected (commit 4862f9f). These stay [I] and still need a check or a device test: `safeAreaInsets` and auxiliary-area availability (ARCHITECTURE §7), the Carbon hot-key API, own-memory reads via Mach task info, and the CoreAudio device list and system volume (FEATURE_MATRIX). The ones that change plans:
- **Clipboard:** "ask on programmatic access" from macOS 15.4; Always Deny fails silently [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum]; `detectedPatterns(for:)` works "without notifying the person using the app" but only reports matches [V: https://developer.apple.com/documentation/appkit/nspasteboard/detectedpatterns(for:)]; Apple defines no concealed or transient type, so the markers are the nspasteboard.org convention [V: https://developer.apple.com/documentation/appkit/nspasteboard/pasteboardtype].
- **Screen capture:** Apple says not to use `sharingType` to hide content [V].
- **Logging:** `os.Logger` redacts strings by default but not numbers [V].
- **Displays:** a display ID typically stays constant until the machine restarts [V: https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid], so a saved display choice falls back to the built-in display when no match is found.
- **Remaining [I] tags:** apart from the list above, these are about Atoll, Canopy or MediaRemote, design reasoning, or things only a device can confirm. The device checks are listed in TASK.md step i.

## 3. What this means for D7

**Recommendation: clipboard history stays in the MVP, with three design changes.** It doesn't need to move to v0.2: reads worked under `alwaysAllow`, and no alert was reported under that setting. But Apple documents "ask" as the default, so the design has to handle it rather than rely on this Mac's `alwaysAllow`.

1. **Check `accessBehavior` when the user turns clipboard history on** (macOS 15.4+, behind `#available`; the target is 14.0).
   - `alwaysAllow`: start watching.
   - `ask` or `default`: show our own explanation first ("macOS may ask whether DropNotch can read the clipboard"), then start.
   - `alwaysDeny`: don't start; show a "blocked in System Settings" state instead of an empty history.
2. **Read in the cheapest order:** `changeCount` on the timer, then `types` only when it changes, skip concealed and transient items, and only then read the content. This limits how often content is read, if "ask" counts each read [I].
3. **Re-check `accessBehavior` on each read** and stop watching if it becomes `alwaysDeny`, because Apple says denied access fails silently [V].

Still to confirm on a device under "ask" (TASK.md step i): whether reading `changeCount` or `types` alone triggers the alert, and whether `changeCount` still works under Always Deny.

## 4. Preview-flag run (partial)

Shash asked for a run under Apple's developer-preview flag for the pasteboard privacy alert: `defaults write com.shashwat.ClipboardProbe EnablePasteboardPrivacyDeveloperPreview -bool yes`.

- **The flag works on macOS 27.0.1 (26A434):** with it set, `accessBehavior` at launch was `default` instead of `alwaysAllow` [V: probe log, two launches].
- **Change count (copies 1–2) and types (copy 3): no alert** under the preview setting [V: probe log; no alert reported by Shash, two runs].
- **Detection call (copy 4) and text reads (copies 5–6): untested.** In both preview runs the probe aborted at copy 4. The cause was a bug in the probe, not macOS: it called `detectedPatterns(for:)` from a Swift `Task` that wasn't on the main thread, and under `default` AppKit waited on a main-thread-only run loop and threw `NSInternalInconsistencyException` ("-[HIRunLoopSemaphore wait:] has been invoked on a secondary thread") [V: captured stderr, run 4]. Under `alwaysAllow` the same call didn't take that path. The probe was fixed (`Task { @MainActor in … }`), but testing was paused before a re-run.
- **Follow-ups:** D7b (pasteboard calls on the main thread). Re-running copies 4–6 under the preview flag is the first step of the Clipboard module (TASK.md).
- The flag was deleted afterwards: `defaults delete com.shashwat.ClipboardProbe EnablePasteboardPrivacyDeveloperPreview` [V: `defaults read` reports the key missing].


## 5. Preview-flag re-run of copies 4–6 (2026-10-31)

First step of the Clipboard module (TASK.md). Same probe design as §1, rebuilt in the session scratchpad with the main-actor fix (D7b): every pasteboard call, including the `detectedPatterns(for:)` await, runs on the main thread. Ad-hoc signed with the hardened runtime (`flags=0x10002(adhoc,runtime)`) [V: `codesign -dv`]. macOS 27.0.1 (26A434) [V: probe log]. Preview flag set with `defaults write com.shashwat.ClipboardProbe EnablePasteboardPrivacyDeveloperPreview -bool yes`. No clipboard or notch app running apart from a Debug DropNotch, which has no clipboard code [V: `lsappinfo`]. Copies made with `pbcopy`, 4 s apart; Shash watched the screen.

| Copy | Read | Result | Time taken | `accessBehavior` after |
|---|---|---|---|---|
| — | at launch | changeCount 102 | — | `default` |
| 4 | `detectedPatterns(for:)` (web URL, number), awaited on the main actor | 0 matched, no crash, no alert | 0.06 s | `default` |
| 5 | string | **blocked the main thread until Shash answered an alert**; returned `nil` | 149.44 s | `ask` |
| 6 | string (copied while copy 5 was blocked) | 22 characters, no second alert reported | 0.00 s | `ask` |

[V: probe log; alert reported by Shash, who clicked Allow. The wording and buttons weren't noted.]

What this shows:
- **The detection call doesn't alert and doesn't crash on the main thread** under the preview setting [V]. D7b holds.
- **A text read under `default` raises the alert and blocks the calling thread until the user answers** [V: 149 s inside `string(forType:)`]. On the main thread (D7b) that would freeze the whole notch: no hover, no animation, no hotkey.
- **After the first alert the setting is `ask`, not `alwaysAllow`**, even though Shash clicked Allow [V]. Apple documents this: the first alert moves the app from `default` to `ask` and lists it in System Settings [V: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum/default]. The pane is Privacy & Security › **Paste from Other Apps** [V: `PASTEBOARD_ACCESS` in SecurityPrivacyExtension.appex's English strings]. The same strings warn that a change there may apply only after the app is quit [V: `PASTEBOARD_ACCESS_QUIT_ALLOW_TITLE`].
- The copy 5 read returned `nil` after Allow. Copy 6 had replaced the clipboard during the wait, which is probably why [I]. Copy 6's read 40 ms later gave no second alert [V: none reported]; whether Allow covers a short window or the rest of the session is unknown [I].
- Apple says access under `ask` that is "both user originated and paste related" is always allowed with no alert [V: …/accessbehavior-swift.enum/ask]. Whether a button click in DropNotch counts as that is untested [I].

Follow-up: D7c. The flag was deleted afterwards (`defaults read` reports the key missing) and the probe quit on its own after copy 6 [V].
