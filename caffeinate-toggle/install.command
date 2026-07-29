#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/../scripts/install-app.sh" "$DIR" "Caffeinate Toggle"
echo
echo "Done. You can close this window."
