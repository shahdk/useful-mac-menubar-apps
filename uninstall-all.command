#!/bin/bash
set -euo pipefail

APPS=("Caffeinate Toggle" "Menubar Calendar" "Claude Usage Monitor")
echo "Uninstalling menubar apps..."
for name in "${APPS[@]}"; do
  osascript -e "tell application \"$name\" to quit" >/dev/null 2>&1 || true
  pkill -f "$name.app/Contents/MacOS/" >/dev/null 2>&1 || true
  for dir in "/Applications" "$HOME/Applications"; do
    if [ -d "$dir/$name.app" ]; then
      rm -rf "$dir/$name.app"
      echo "Removed $dir/$name.app"
    fi
  done
done
echo "Done. You can close this window."
