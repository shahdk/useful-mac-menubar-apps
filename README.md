# useful-mac-menubar-apps

A small collection of useful macOS menubar apps you can install on your machine with a
single click. Each app is a self-contained, native **Swift** menubar app — no third-party
dependencies, no `brew`/`pip` installs, and because they're compiled locally, **no Gatekeeper
"unidentified developer" prompts**.

## The apps

| App | What it does |
| --- | --- |
| ☕ [**Caffeinate Toggle**](caffeinate-toggle/) | Toggle `caffeinate -ds` (keep display + system awake) from the menubar; terminates the process when toggled off. |
| 📅 [**Menubar Calendar**](menubar-calendar/) | Shows today's date number in the menubar (`29`); click for a month calendar with today highlighted. |
| 🧠 [**Claude Usage Monitor**](claude-usage-monitor/) | Shows your real Claude Code session usage (via `claude -p "/usage"`); gently pulses the screen edges red when you pass a threshold. Requires the Claude CLI. |

## Install everything (single click)

Double-click **`install-all.command`** in this folder. It compiles and installs all three
apps to `/Applications` and launches them.

Or install one at a time — double-click the **`install.command`** inside any app's folder.

## Update

Double-click **`update-all.command`**. It pulls the latest source (if this is a git
checkout), rebuilds every app, then quits and relaunches the fresh build. To update a
single app, just re-run its **`install.command`** — it always rebuilds from the current
source.

## Requirements

- **macOS 13 (Ventura) or later**
- **Xcode Command Line Tools** (provides the Swift compiler used once at install time):

  ```sh
  xcode-select --install
  ```

That's it — no other dependencies.

## Uninstall

Double-click **`uninstall-all.command`** to quit and remove all three apps, or quit an
individual app from its menu and delete its `.app` from `/Applications`.

## Repo layout

```
├── install-all.command        # build + install all apps
├── update-all.command         # git pull + rebuild + relaunch all apps
├── uninstall-all.command      # remove all apps
├── scripts/
│   ├── build-app.sh           # shared: compile a Sources/main.swift into an .app bundle
│   └── install-app.sh         # shared: build, copy to /Applications, launch
├── caffeinate-toggle/
│   ├── Sources/main.swift
│   ├── build.sh · install.command · README.md
├── menubar-calendar/
│   ├── Sources/main.swift
│   ├── build.sh · install.command · README.md
└── claude-usage-monitor/
    ├── Sources/main.swift
    ├── build.sh · install.command · README.md
```

Each app compiles from a single `Sources/main.swift` using `swiftc`, producing a menubar-only
(`LSUIElement`) `.app` bundle. See each app's README for details.

## Notes

- All apps run menubar-only (no Dock icon) and offer a **Start at Login** toggle.
- Build output (`*/build/`) is git-ignored; installers regenerate it.
- **Claude Usage Monitor** requires the [Claude CLI](https://docs.claude.com/claude-code) installed and logged in — it shows the official `/usage` session percentage, run locally on your machine. It runs `claude` through your login shell, so it uses the same `claude` your Terminal does. If usage won't load, run `claude update` — older CLIs omit the `Current session:` line. See its [README](claude-usage-monitor/README.md).

## Contributing

Contributions are welcome — bug fixes, new menubar apps, and docs. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to build locally and add an app.

## License

[MIT](LICENSE) © Dharmin Shah
