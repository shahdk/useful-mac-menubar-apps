#!/bin/bash
# Update all installed menubar apps by running each app's own update.command.
# Each one pulls the latest source (git pull is a no-op after the first),
# rebuilds, reinstalls, quits the running copy, and relaunches it.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Updating menubar apps..."
echo

"$DIR/caffeinate-toggle/update.command"
echo
"$DIR/menubar-calendar/update.command"
echo
"$DIR/claude-usage-monitor/update.command"
echo
echo "All apps updated and relaunched. You can close this window."
