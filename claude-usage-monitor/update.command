#!/bin/bash
# Update just this app: pull the latest source (if this is a git checkout),
# then rebuild, reinstall, and relaunch it.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"

# This app needs the Claude CLI to read `/usage`.
if ! command -v claude >/dev/null 2>&1; then
  echo "⚠  The Claude CLI ('claude') was not found on your PATH."
  echo
  echo "   Claude Usage Monitor reads your usage by running:  claude -p \"/usage\""
  echo "   Please install it and log in first:"
  echo
  echo "     1. Install:  npm install -g @anthropic-ai/claude-code"
  echo "                  (or see https://docs.claude.com/claude-code )"
  echo "     2. Log in:   run  claude  in Terminal and follow the sign-in prompts"
  echo "     3. Verify:   claude -p \"/usage\"   should print a 'Current session:' line"
  echo
  echo "   Then re-run this updater."
  echo
  read -r -p "Press Return to close..." _ || true
  exit 1
fi

echo "✓ Claude CLI found: $(command -v claude)"
echo

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

"$DIR/../scripts/install-app.sh" "$DIR" "Claude Usage Monitor"
echo
echo "Done. You can close this window."
