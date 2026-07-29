#!/bin/bash
# Shared installer: builds the app, copies it to /Applications (or ~/Applications),
# quits any running copy, and launches the freshly installed one.
# Usage: install-app.sh <app-dir> "<App Name>"
set -euo pipefail

APP_DIR="$1"
APP_NAME="$2"

echo "== Installing $APP_NAME =="
"$APP_DIR/build.sh"

SRC="$APP_DIR/build/$APP_NAME.app"
DEST_DIR="/Applications"
if [ ! -w "$DEST_DIR" ]; then
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
fi
DEST="$DEST_DIR/$APP_NAME.app"

# Quit a running copy so we can overwrite it.
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_NAME.app/Contents/MacOS/" >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Strip the quarantine flag just in case (locally built, but harmless).
xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true

open "$DEST"
echo "Installed to: $DEST"
echo "$APP_NAME is now running in your menubar."
