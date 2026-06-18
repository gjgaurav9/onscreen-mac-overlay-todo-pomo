# On-Screen Pomodoro

A minimal **always-on-top** Pomodoro timer for macOS. It floats above whatever
you're working in — browser, Cursor, terminal, even fullscreen apps and across
every Space — so you can feel time slipping without ever switching windows.

Native Swift + AppKit/SwiftUI. No Electron, no menu-bar clutter, no Dock icon.

```
   ╭───────────╮
   │   ◜‾‾‾◝    │
   │  ◜ 24:13 ◝ │     ← depleting ring, time inside it
   │  ◟ FOCUS ◞ │
   │   ◟___◞    │
   │  ● ● ○ ○   │     ← sessions until the next long break
   ╰───────────╯
```

## Features at a glance

**Timer**
- Always-on-top floating overlay above any app, all Spaces, and fullscreen windows.
- Pomodoro cycle: focus → short break → long break (every 4th focus), auto-cycling.
- Smoothly depleting progress ring with `mm:ss` inside; calm cool color at rest, red
  only in the final 1–2 minutes.
- Session dots show progress toward the next long break.
- Hover for play/pause, reset, skip; right-click menu for the same + Focus Lock + quit.
- Drag anywhere to reposition; position is remembered. Soft chime at each boundary.
- **Minimize** (hover → `–` top-right, or right-click → Minimize) collapses the whole
  app to a thin phase-tinted line; click the line to expand it back.
- Never steals focus; no Dock icon, no menu-bar clutter.

**To-do list (accordion under the timer)**
- Expand/collapse a small task drawer below the ring — never full-screen, never a
  separate window; the timer stays the main element and the panel grows downward.
- Add tasks (Enter), check off, delete on hover, "Clear completed".
- **Drag to reorder** by priority; **tap a task** to promote it to current and collapse.
- Collapsed bar shows your **current task** (top unchecked) for single-tasking.
- **Hover a task to see its full text** (wraps); truncated to one line otherwise.
- Paste (⌘V/⌘C/⌘X/⌘A) and dictation (e.g. Wispr Flow) work in the task field.
- Tasks persist across launches.

**Focus Lock (opt-in)**
- While a focus phase runs, switching to a non-allowed app is intercepted: it's hidden
  and a calm overlay defaults you back, with a deliberate **hold-to-unlock (3s)** escape.
- Pinned to the app you started in + a comms allowlist; never blocks force-quit or the
  lock screen. Zero system permissions.

## Run it

```bash
./build-app.sh        # compiles + packages Pomodoro.app (ad-hoc signed)
open Pomodoro.app     # floats into the top-right corner
```

Install permanently: `cp -r Pomodoro.app /Applications/` (then add to Login Items
if you want it on every boot).

Or run straight from source: `swift run -c release`.

## Using it

- **Hover** the widget → play/pause, reset, skip controls appear.
- **Drag** anywhere on the body to reposition (the spot is remembered per launch).
- **Right-click** → start/pause, reset, skip, toggle Focus Lock, quit.
- It **never steals focus** — clicking it won't pull you out of your editor (the
  to-do field can still take typing while your app stays the active one).

## Tasks (accordion)

Click the **task bar** under the timer to expand a small to-do drawer *below* the
ring — never a full screen, never a separate window. Type a task and hit Enter; check
items off; delete on hover.

- **Reorder by priority:** drag a task up or down to set its order.
- **Choose a task:** tap a task's title to promote it to the top and collapse the
  drawer back to the small view — so the timer + your chosen task are all you see.
- When collapsed, the bar shows your **current task** (the top unchecked one) so the
  thing you're meant to be doing stays glanceable (supports single-tasking).
- Tasks persist across launches. The timer always stays the main, fixed element; the
  list just grows the panel downward.

**Text input (paste / dictation):** the overlay normally never activates the app (so
it can't steal focus), but that also blocks ⌘V and tools like Wispr Flow. So the app
**activates only while you're editing tasks** (opening the drawer or focusing the
field), which makes paste, ⌘C/⌘V/⌘A, and dictation work normally. Click back into your
editor and the overlay goes passive again.

## Focus Lock

Right-click → **Focus Lock** (a 🔒 appears on the widget). While a focus phase is
running, drifting to another app gets intercepted: the app you jumped to is hidden
again and a calm full-screen overlay defaults you back to focus. To actually leave,
**hold "Unlock" for 3 seconds** — a deliberate beat, not an unbreakable cage.

What stays allowed: the app you were in when the phase started (pinned automatically),
plus an emergency comms allowlist (Messages, FaceTime, Calendar, Reminders). It
**never** blocks force-quit (⌥⌘⎋) or the lock screen.

This is a deliberate design choice grounded in the research (see below): a soft
friction interceptor beats a hard lock. macOS also can't truly imprison you in another
app without MDM — so "lock" here means *remove the reflex's payoff + add a deliberate
escape*, which is also what the evidence says works best (one sec / PNAS 2023: ~57%
fewer distracting opens, and the easy back-out option carried the effect). A no-escape
lock backfires via reactance (Brehm), undermined autonomy (SDT), and comms-separation
anxiety. Tier 1 needs **zero system permissions**.

## How it works (the windowing trick)

`OverlayPanel` is a borderless, non-activating `NSPanel` at `.floating` level with
`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`.
That combination is what lets it sit on top of *any* app, follow you across Spaces,
and ride over fullscreen windows. The `.nonactivatingPanel` style keeps your real app
the active one even when the overlay is clicked, so it never pulls focus during normal
use. The app runs as an `.accessory` (no Dock icon).

The panel *can* become key (`canBecomeKey = true`) so the to-do text field accepts
typing — but because it's non-activating, becoming key doesn't activate the app. The
one exception is editing tasks: we deliberately call `NSApp.activate` while the drawer
is open so paste and dictation land in the field, then go passive again afterward.
The panel auto-sizes to its SwiftUI content via an `NSHostingController` with
`.preferredContentSize`, with the top-left pinned so the accordion grows downward.

## Defaults

| Phase | Length |
|-------|--------|
| Focus | 25 min |
| Short break | 5 min |
| Long break (every 4 focus sessions) | 15 min |

Breaks auto-start; returning to focus is a deliberate tap. All durations and
behaviours live in `Settings.swift` (persisted via `UserDefaults`).

## Design rationale (it's psychology, not decoration)

The visual choices are deliberate and evidence-based — **design for calm
awareness, not urgency**:

- **A smoothly depleting ring with the time inside it.** A percent-done style ring
  reduces uncertainty and reads pre-attentively from the periphery (Calm
  Technology; NN/g progress research). As it nears empty it becomes a literal
  **goal gradient** (Hull 1932; Kivetz et al. 2006) — the end-of-session sprint.
- **Calm cool color at rest; red only in the final 1–2 minutes.** Persistent red
  reads as "alarm/error" and induces low-grade stress. A 2025 BMC Psychology study
  (N=7,536) found *feeling harried* — not mere awareness of time — drives anxiety;
  an informational countdown stays on the benign side, an urgent-styled one doesn't.
- **Never interrupts mid-focus.** No modal, no flashing, no focus-stealing. One soft
  chime at each boundary (operant reinforcement — consistent, not gamified-random).
  Interruptions cost ~23 min of recovery (Mark) and leave attention residue (Leroy).
- **Configurable intervals.** 25/5 is Cirillo's kitchen-timer heuristic, not an
  optimum. Breaks are justified by the **vigilance decrement** (Mackworth 1948), not
  the discredited "willpower runs out" (ego depletion failed to replicate).
- **Session dots** give a gentle accumulation cue (endowed-progress effect, Nunes &
  Drèze 2006) toward the next long break.

See `CLAUDE.md` for the full design brief and source list.
