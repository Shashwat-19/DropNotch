# TASK: Reverse-engineering analysis + foundation

Rules, commands and constraints are in CLAUDE.md. Follow them throughout.

## Goal
Run a reverse-engineering analysis (REA) of Canopy and Atoll, turn it into a feature matrix and architecture plan for DropNotch, then scaffold the foundation. DropNotch must be original code that Shash owns.

## Phase 1: Analysis (no app code yet)
1. Use the `reference-analyst` agent to fetch Canopy's three public pages (https://getcanopy.pro, /changelog, /privacy). List every feature and behavioural claim, e.g. event-driven instead of polling, idle memory, external/non-notch display support, lock-screen music and lyrics, AirPods battery and volume, charging indicator, weather, privacy stance.
2. Use the `reference-analyst` agent to clone Atoll (https://github.com/Ebullioscopic/Atoll) into ./reference/atoll. Check out tag v2.3.3-alpha.4 if it exists; otherwise use the closest tag and report which. Inventory its features from the README and source. For each feature, note the frameworks/APIs used (public vs private/undocumented), the permissions required (Accessibility, Screen Recording, Location, Calendars, Bluetooth), and the files where it lives. Notes go in docs/research/, in the analyst's own words, with no code.
3. Write docs/FEATURE_MATRIX.md, one row per feature:
   Feature | Canopy | Atoll | macOS API / approach | Public or private | Permissions | Breakage risk on macOS updates | DropNotch priority (MVP / v0.2 / later / skip) | Notes
   Merge in DropNotch's own list:
   - Main screen: song icon on the left and waveform on the right while playing; hover to expand; user-chosen calendar or notes panel; file tray with AirDrop; timer; notes; terminal; clipboard history; Mac battery; AirPods battery with connect animation; animals on the left when nothing is playing.
   - Lock screen: Mac battery, audio-device battery, AQI, temperature, full-screen now playing.
   MVP is: music controls, file tray + AirDrop, clipboard history, quick notes, and a customisable notch layout. Judge features by how fast a frequent action gets done.
4. Write docs/ARCHITECTURE.md: module layout, the protocol every feature module implements (compact view, expanded view, settings view, enabled flag), state management, persistence, notch panel window configuration, handling of notch vs non-notch/external displays, and an energy budget listing what is event-driven, what genuinely needs polling, and at what interval.
5. Write docs/RISKS.md: private APIs (MediaRemote restrictions since macOS 15.4, AirPods battery, drawing on the lock screen), permission UX, and distribution outside the App Store (Developer ID, notarisation, DMG, Sparkle updates).
6. STOP. Summarise the 10 decisions you need from Shash and wait for approval.

## Phase 2: Foundation (only after Phase 1 is approved)
Use the `planner` agent first, then implement.
- LSUIElement = YES (no Dock icon), set through project.yml. Add a menu-bar item with Settings and Quit.
- NotchPanel: a borderless, non-activating NSPanel above the menu bar that joins all Spaces and full-screen apps. Position it from NSScreen.safeAreaInsets and auxiliaryTopLeftArea/auxiliaryTopRightArea. Show a fallback pill on displays without a notch. Reposition on screen-parameter changes.
- Hover state machine: closed → peek → open, with debounce and spring animations. The panel is click-through when closed.
- Module protocol and registry, plus one stub module (Now Playing) rendering a placeholder.
- Unit tests (via `test-writer`) for notch geometry and the hover state machine.
- Run `xcodegen generate`, then `xcodebuild -scheme DropNotch -destination 'platform=macOS' build test`, and report the actual output.
- Finish with `code-reviewer` and `performance-optimizer`, and record decisions in docs/DECISIONS.md.
