#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/../scripts/build-app.sh" "$DIR" "Menubar Calendar" "MenubarCalendar" "com.usefulmenubar.calendar"
