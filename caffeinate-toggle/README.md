# ☕ Caffeinate Toggle

A tiny macOS menubar app that keeps your Mac awake by toggling
[`caffeinate -ds`](x-man-page://caffeinate) on and off. When you toggle it off, the
underlying `caffeinate` process is terminated immediately — no lingering processes.

- `-d` — prevents the **display** from sleeping
- `-s` — prevents the **system** from sleeping (when on AC power)

## Install (single click)

1. Double-click **`install.command`** in this folder.
2. A Terminal window opens, compiles the app, installs it to `/Applications`, and launches it.
3. A cup icon appears in your menubar.

> Built locally with Swift, so there are no Gatekeeper "unidentified developer" prompts
> and no third-party dependencies.

## Usage

| Action | Result |
| --- | --- |
| **Left-click** the icon | Toggle keep-awake on/off |
| **Right-click** (or ⌃-click) | Menu: *Start at Login*, *Quit* |

The icon fills in and turns **orange** when keep-awake is **ON**, and is a plain outline when **OFF**.
Quitting the app (or toggling off) terminates the `caffeinate` process.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (for the one-time compile): `xcode-select --install`

## Uninstall

Quit the app from its menu, then delete `Caffeinate Toggle.app` from `/Applications`
(or run `uninstall-all.command` in the repo root).

## How it works

The app is a menubar-only (`LSUIElement`) Swift app. Toggling on launches
`/usr/bin/caffeinate -ds` as a child `Process`; toggling off (or quitting) calls
`terminate()` on it. Source: [`Sources/main.swift`](Sources/main.swift).
