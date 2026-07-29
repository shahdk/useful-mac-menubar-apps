#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/../scripts/build-app.sh" "$DIR" "Claude Usage Monitor" "ClaudeUsageMonitor" "com.usefulmenubar.claudeusage"
