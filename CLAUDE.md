# CLAUDE.md — On-Screen Pomodoro

Handoff/context doc for any Claude Code session working on this repo. Read this first.

## What this project is

A **native macOS always-on-top Pomodoro overlay**. A small floating widget that sits
on top of whatever app the user is working in (browser, Cursor, terminal) — including
fullscreen apps and across all Spaces — so they can *see time slipping* without
window-switching. Lightweight native Swift, not Electron.

**Guiding principle (do not break):** it is an *ambient, peripheral* tool. It must
**never steal focus** from the user's real app, **never interrupt mid-focus** (no
modals/flashing/focus-stealing), and stay **calm** (cool colors at rest; red is
reserved strictly for the final 1–2 minutes of a focus phase). Design for *calm
awareness, not urgency*.

## Tech / how to build

- Swift Package Manager executable target, AppKit + SwiftUI, macOS 13+. No deps.
- `swift build -c release` to compile; `swift run -c release` to run from source.
- `./build-app.sh` → assembles a double-clickable, ad-hoc-signed `Pomodoro.app`
  (`LSUIElement = true`, so no Dock icon / menu-bar name — a pure overlay).
- `.build/` and `Pomodoro.app/` are gitignored; rebuild them, don't commit them.

## Architecture (Sources/Pomodoro/)

- `main.swift` — `NSApplication` entry, `.accessory` activation policy, `AppDelegate`
  builds the panel + positions it (top-right default, persists per move).
- `OverlayPanel.swift` — borderless **non-activating** `NSPanel`, `level = .floating`,
  `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary,
  .ignoresCycle]`, `canBecomeKey/Main = false`. **This file is the "float on top of
  everything" magic — change it carefully.**
- `TimerEngine.swift` — `ObservableObject` state machine + clock. Time is computed
  from an absolute `endDate` (drift-free), not by decrementing. Phase cycle:
  focus → short break → (long break every Nth) → focus. `isUrgent` gates the red.
- `TimerView.swift` — SwiftUI face: depleting ring + mm:ss inside, session dots,
  hover controls (play/pause/reset/skip), right-click menu. Accent color logic lives
  here (cool at rest, red only when `isUrgent`).
- `Settings.swift` — `UserDefaults`-backed prefs (durations, auto-start, sound,
  showSeconds, focusLock, saved panel origin). 25/5/15 + long break every 4 are defaults only.
- `FocusLockController.swift` — Tier-1 Focus Lock (no permissions). Engaged by
  `AppDelegate` via Combine when armed + running + focus phase + not suspended. On
  drift (a non-allowed app activates), it `hide()`s that app and raises a full-screen
  `LockOverlayView` shield at `CGShieldingWindowLevel()`. Pinned to the app that was
  frontmost at engage (tracked as `lastForegroundApp` in AppDelegate); comms allowlist
  always passes. Hold-to-unlock (3s) sets `engine.lockSuspended` → disengages.
- `LockOverlayView.swift` — the friction interstitial (Return-to-focus primary action
  + hold-to-unlock escape). `KeyableWindow` subclass lets the borderless shield become
  key so it can receive the hold gesture.

### Focus Lock design constraints (do not break)
- **Soft friction, not a hard cage.** Default to intercept-and-default-back with an
  always-available deliberate escape. Evidence (one sec/PNAS 2023; reactance; SDT;
  nomophobia) says a no-escape lock backfires. The escape carries the benefit.
- **Never block** force-quit (⌥⌘⎋) or the lock screen. Keep the comms allowlist.
- macOS can't truly lock a user *into* another app without MDM/supervision — don't
  promise that. We remove the switch's payoff (hide + overlay), we don't cage the OS.
- Tier 2 (CGEventTap swallowing Cmd-Tab, needs Accessibility) was researched and
  deliberately NOT built — Tier 1 was chosen to stay permission-free. See git history.

## Repo conventions (important)

- **Commit authorship:** commits here must be authored **only** as
  `gjgaurav9 <gjgaurav9@gmail.com>` with **NO `Co-Authored-By: Claude` trailer** and
  no Claude mention in commit messages or PR bodies. (`git config user.*` already
  resolves to this in-repo via the `my_projects` git setup.)

## Design brief (evidence-based — the "why" behind the UI)

Lead with the well-supported principles; avoid the debunked ones.

- **Lead with:** scarcity/focus-dividend (Shah/Mullainathan/Shafir 2012), goal-gradient
  (Hull 1932; Kivetz et al. 2006) + endowed progress (Nunes & Drèze 2006), vigilance
  decrement (Mackworth 1948), implementation intentions (Gollwitzer; d≈0.65), Calm
  Technology (Weiser & Brown 1996), and "feeling harried vs cognitive time-awareness"
  (BMC Psychology 2025, N=7,536 — harried drives anxiety, mere awareness doesn't).
- **Framing only:** Parkinson's Law, 52/17, 90-min ultradian — recognizable, not rigorous.
- **Avoid / don't claim:** ego depletion / "willpower runs out" (failed replication),
  Zeigarnik *memory* effect (use resumption/Ovsiankina instead), deterministic color
  psychology, variable-reward gamification, "21 days to a habit," persistent red.

### Ideas not yet built (good next steps)
- If-then implementation-intention onboarding prompt (highest-leverage adherence nudge).
- Streak counter **with a grace/freeze mechanic** (avoid the what-the-hell effect — never
  zero a streak on one miss).
- "Focus mode" that hides the digits (ring only) for the ~25% who over-monitor.
- Optional click-through (`ignoresMouseEvents`) pure-ambient mode.
- A small settings UI for durations (currently edited in `Settings.swift`).
