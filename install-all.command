#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing all menubar apps..."
echo
"$DIR/scripts/install-app.sh" "$DIR/caffeinate-toggle"    "Caffeinate Toggle"
echo
"$DIR/scripts/install-app.sh" "$DIR/menubar-calendar"     "Menubar Calendar"
echo
"$DIR/scripts/install-app.sh" "$DIR/claude-usage-monitor" "Claude Usage Monitor"
echo
echo "All apps installed and running in your menubar. You can close this window."
