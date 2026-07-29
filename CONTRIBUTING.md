# Contributing

Thanks for your interest in improving these menubar apps! Contributions of all
sizes are welcome — bug fixes, new apps, docs, or ideas.

## Getting set up

You only need macOS 13+ and the Xcode Command Line Tools:

```sh
xcode-select --install
```

There are no third-party dependencies. Each app is a single
`Sources/main.swift` compiled with `swiftc` into an `LSUIElement` (menubar-only)
`.app` bundle.

## Building locally

Build one app:

```sh
./caffeinate-toggle/build.sh   # output in caffeinate-toggle/build/
```

Build and install one app to `/Applications`:

```sh
./caffeinate-toggle/install.command
```

Build every app at once:

```sh
for app in caffeinate-toggle menubar-calendar claude-usage-monitor; do
  "$app/build.sh"
done
```

CI runs this same build on every pull request, so please make sure all three
apps compile before opening one.

## Running tests

Pure logic (currently the `claude-usage-monitor` `/usage` output parser) is kept
free of AppKit so it can be unit-tested with just the Swift compiler — no test
framework to install:

```sh
./claude-usage-monitor/test.sh
```

CI runs this too. If you extract other pure logic into its own
`Sources/*.swift` file, add cases under that app's `Tests/` and a `test.sh`
following the same pattern.

## Adding a new app

1. Create a folder `your-app/` with a `Sources/main.swift`.
2. Add a `build.sh` that calls the shared builder — copy an existing app's
   `build.sh` and change the app name, executable name, and bundle id:

   ```sh
   "$DIR/../scripts/build-app.sh" "$DIR" "Your App" "YourApp" "com.usefulmenubar.yourapp"
   ```

3. Add an `install.command` and `update.command` (copy an existing app's and
   swap the app name).
4. Wire the app into `install-all.command`, `update-all.command`, and
   `uninstall-all.command`.
5. Add a `README.md` in the app folder and a row to the table in the root
   `README.md`.

## Guidelines

- Keep apps dependency-free and self-contained — no `brew`/`pip`/SPM packages.
- Match the style of the existing Swift code.
- Keep each app to a single `Sources/main.swift` where practical.
- Test that the app launches and behaves as expected in the menubar before
  submitting.

## Submitting changes

Open a pull request against `main` with a clear description of what changed and
why. Small, focused PRs are easiest to review.
