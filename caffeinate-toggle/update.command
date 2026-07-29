#!/bin/bash
# Update just this app: pull the latest source (if this is a git checkout),
# then rebuild, reinstall, and relaunch it.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"

if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "== Fetching latest source =="
  if git -C "$ROOT" pull --ff-only; then
    echo "Source updated."
  else
    echo "warning: could not fast-forward (local changes?). Rebuilding current source instead." >&2
  fi
  echo
else
  echo "Not a git checkout — rebuilding the current source."
  echo
fi

"$DIR/../scripts/install-app.sh" "$DIR" "Caffeinate Toggle"
echo
echo "Done. You can close this window."
