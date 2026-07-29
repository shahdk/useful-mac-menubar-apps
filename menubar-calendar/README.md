# 📅 Menubar Calendar

A minimal macOS menubar calendar. The menubar shows **today's date number** (just `29`
on July 29). Click it to open a month calendar with today highlighted and the full
weekday/date spelled out.

## Install (single click)

1. Double-click **`install.command`** in this folder.
2. A Terminal window compiles the app, installs it to `/Applications`, and launches it.
3. Today's date number appears in your menubar.

> Built locally with Swift — no Gatekeeper prompts, no third-party dependencies.

## Usage

| Action | Result |
| --- | --- |
| **Left-click** the date | Open the calendar popover |
| ◀ / ▶ in the popover | Previous / next month |
| **Today** button | Jump back to the current month |
| **Right-click** (or ⌃-click) | Menu: *Start at Login*, *Quit* |

The popover shows:

- The full date at the top — e.g. **Wednesday, July 29, 2026**
- The current month grid, with **today circled in red**
- Locale-aware weekday order (respects your system's first-day-of-week)

The menubar number updates automatically at midnight.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (for the one-time compile): `xcode-select --install`

## Uninstall

Quit the app from its menu, then delete `Menubar Calendar.app` from `/Applications`
(or run `uninstall-all.command` in the repo root).

## How it works

A menubar-only (`LSUIElement`) Swift app. The status item's title is formatted with
`DateFormatter` (`"d"`); the popover hosts a hand-drawn `CalendarView` grid. It refreshes
on the system `NSCalendarDayChanged` notification. Source: [`Sources/main.swift`](Sources/main.swift).
