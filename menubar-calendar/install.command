#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/../scripts/install-app.sh" "$DIR" "Menubar Calendar"
echo
echo "Done. You can close this window."
