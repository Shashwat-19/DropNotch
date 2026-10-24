# CLAUDE.md — DropNotch

## Project overview
DropNotch is an open-source macOS utility that turns the MacBook notch into a productivity surface: now-playing controls, a file tray with AirDrop, clipboard history and quick notes. It expands on hover or hotkey and stays minimal otherwise. Productivity first, visual customisation second: a feature earns its place by making a frequent action faster, not by adding another widget.

Maintainer: Shash. Strong in Python and TypeScript, new to Swift. Briefly explain non-obvious Swift/AppKit decisions in code comments and in docs/DECISIONS.md.

## Tech stack
- Swift (Swift 5 language mode, set in project.yml), SwiftUI for views, AppKit for windowing and system hooks
- macOS 14.0+ deployment target; Apple silicon; Xcode 27.1
- XcodeGen: `project.yml` generates the Xcode project
- Tests: XCTest in DropNotchTests
- Distribution: DMG on GitHub Releases (Developer ID signing + notarisation once there is an Apple Developer account); Sparkle for updates (not added yet)
- Not on the Mac App Store (private APIs). No Python, no Electron, no web views for app UI.

## Directory structure
```
project.yml          # source of truth for the Xcode project
DropNotch/           # app sources (feature code under DropNotch/Modules/<Feature>/)
DropNotchTests/      # unit tests
docs/                # FEATURE_MATRIX, ARCHITECTURE, RISKS, DECISIONS, research/
reference/           # cloned reference apps: gitignored, never built, never copied from
.claude/agents/      # sub-agents for this repo
TASK.md              # the current task; replaced as work moves on
```
Once docs/ARCHITECTURE.md exists it is the source of truth for module layout. Keep this section in sync with it.

## Commands
- Regenerate project (after any project.yml change, and after adding/removing files): `xcodegen generate`
- Build + test: `xcodebuild -scheme DropNotch -destination 'platform=macOS' build test`
- Errors only: append `2>&1 | grep -E "error:|warning:|failed" | head -40`
- Result only: append `2>&1 | tail -20`
- App logs: `log stream --predicate 'subsystem == "com.shashwat.DropNotch"' --level debug`

## Critical constraints

### Ownership and licences (non-negotiable)
1. Canopy (getcanopy.pro) is closed-source and paid. Use public material only: the homepage, /changelog and /privacy. Never download, decompile, disassemble, class-dump, or inspect its binary or bundled resources.
2. Atoll and Boring Notch are GPL-3.0. Reading their source to learn which APIs and techniques they use is fine. Copying, pasting or closely paraphrasing their code, assets or UI strings into DropNotch is not.
3. Clean-room split: only the `reference-analyst` agent reads ./reference/. It writes technique notes in its own words to docs/research/. Implementation work uses those notes and Apple documentation, not ./reference/.
4. Every dependency: record its licence in docs/DECISIONS.md and confirm DropNotch can still be licensed as MIT or GPL-3.0.

### Project
- Never edit DropNotch.xcodeproj; it is generated and gitignored. Change project.yml (targets, Info.plist keys such as LSUIElement, entitlements, build settings, Swift packages under `packages:`) and run `xcodegen generate`.
- Package.resolved lives inside the gitignored .xcodeproj, so pin packages with `exactVersion:` in project.yml.
- Ask Shash before adding any dependency.
- Private or undocumented APIs (MediaRemote, IOBluetooth battery keys, SkyLight) sit behind a protocol in Services/ with a fallback, so a macOS update disables one feature instead of crashing the app.
- Energy: event-driven by default. Every timer or polling loop needs an interval and a justification in docs/ARCHITECTURE.md. Nothing blocking on the main thread.
- Privacy: no analytics or telemetry. Clipboard history skips concealed/transient pasteboard types, stays on the Mac and is never logged. Request each permission only when the feature that needs it is first enabled.
- No secrets in the repo. Signing identities and notarisation credentials live in the keychain or CI secrets.

### Honesty
- Never claim something builds, runs or passes unless you ran it and saw it pass. Show the real output. Label anything unverified as unverified.
- Find the root cause before fixing. Never disable tests or silence warnings to get a green build.

## Coding conventions
- Swift API Design Guidelines; one primary type per file.
- UI state on `@MainActor`. Services expose async APIs or AsyncStream for events.
- Logging via `os.Logger(subsystem: "com.shashwat.DropNotch", category: "<Module>")`. Never log user content (clipboard, file names, track info).
- British spelling in docs and UI copy (optimise, behaviour, colour).
- Commits: Conventional Commits (feat:, fix:, docs:, test:, refactor:, chore:), small, one feature per branch (`feat/<name>`).
- Record each meaningful decision in docs/DECISIONS.md: the decision, the alternatives, and why.

## Sub-agents (.claude/agents/)
| Agent | Use when |
|---|---|
| planner | Start of any non-trivial feature or fix |
| reference-analyst | Anything about how Canopy/Atoll/Boring Notch work; the only agent that reads ./reference/ |
| test-writer | Logic added or changed |
| code-reviewer | After implementing, before merging |
| debugger | Build failure, failing test, crash, wrong behaviour |
| security-auditor | Changes touching clipboard, file tray, permissions, subprocesses, network, entitlements, updates; before releases |
| performance-optimizer | New timers, observers, animations or background work; before releases |
| accessibility-auditor | Any change to notch or settings UI |
| docs-writer | Setup, behaviour, permissions or architecture changed |
| dependency-manager | Before adding any package; before releases |
| cicd-agent | GitHub Actions build/test/release workflows |
| changelog-agent | Before tagging a release |

Feature workflow: planner → implement → test-writer → code-reviewer → security-auditor / performance-optimizer / accessibility-auditor where relevant → docs-writer.

## Current focus
See TASK.md.

## Definition of done
- `xcodegen generate`, build and tests pass, with output shown
- New logic has tests; anything only verifiable on a real notched Mac is listed for manual checking
- code-reviewer verdict is Approve, or Approve with changes and the changes are made
- docs/DECISIONS.md, README and docs/ARCHITECTURE.md updated if behaviour, setup or structure changed
