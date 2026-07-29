# 🧠 Claude Usage Monitor

A macOS menubar app that shows your **real Claude Code session usage** and pulses the edges
of your screen gently red when you pass a threshold. It gets the number straight from Claude
by running `claude -p "/usage"` and reading the official line:

```
Current session: 37% used · resets Jul 29 at 12:59pm (America/Indianapolis)
```

The menubar shows that session percentage — e.g. `37%` — tinted **orange** as you approach
your threshold and **red** once you're over it. The weekly limit is shown too, for reference.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (one-time compile): `xcode-select --install`
- **The Claude CLI, installed and logged in** — the app reads usage by running it:
  - Install: `npm install -g @anthropic-ai/claude-code` (or see <https://docs.claude.com/claude-code>)
  - Log in: run `claude` in Terminal and follow the sign-in prompts
  - Verify: `claude -p "/usage"` prints a `Current session:` line

## Install (single click)

1. Double-click **`install.command`** in this folder.
2. It first checks that the `claude` CLI is available (and tells you how to install/log in if not).
3. It compiles the app, installs it to `/Applications`, and launches it.
4. Your session percentage appears in the menubar.

> Built locally with Swift — no Gatekeeper prompts, no third-party dependencies.

## Usage

**Left-click** the percentage for the menu:

| Menu item | What it does |
| --- | --- |
| **Session: N% used · resets …** | Your current session usage + reset time |
| **Week: N% used · resets …** | Your weekly usage + reset time |
| **Alert threshold** | Pick the session % that triggers the red edge flash (50–95%) |
| **Refresh now** | Re-run `/usage` immediately |
| **Setup / Help…** | Instructions if the CLI isn't found or logged in |
| **Start at Login** | Launch automatically on login |

Usage auto-refreshes every **5 minutes** (the `/usage` numbers change slowly, and this keeps
the app light). If it can't read usage, the menubar shows **⚠** — click it for setup help.

### The red edge flash

When session usage ≥ your threshold, a translucent, click-through overlay pulses a soft red
vignette around the edges of **all** screens (fading between ~12% and ~55% opacity, ~1.1s per
pulse). It never blocks clicks and disappears the moment usage drops back under the threshold.

## Configuration

Only the alert threshold is configurable (from the menu). It persists to:

```
~/Library/Application Support/ClaudeUsageMonitor/config.json
```

```json
{ "thresholdPercent": 80 }
```

## Privacy

The app only runs the Claude CLI locally and reads its printed output — nothing is sent
anywhere by this app. It reflects usage on **this machine's** account, exactly as `/usage` does.

## Uninstall

Quit the app from its menu, then delete `Claude Usage Monitor.app` from `/Applications`
(or run `uninstall-all.command` in the repo root). Remove the config folder above if desired.

## How it works

A menubar-only (`LSUIElement`) Swift app. A background timer runs `claude -p "/usage"` through
a login shell (so `~/.local/bin` etc. are on `PATH`) off the main thread, parses the
`Current session` / `Current week` lines, and updates the menubar. The flash is a set of
borderless, mouse-ignoring `NSWindow`s (one per screen) at `.screenSaver` level, animated with
`NSAnimationContext`. Source: [`Sources/main.swift`](Sources/main.swift).
