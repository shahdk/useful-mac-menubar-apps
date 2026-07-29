#!/bin/bash
# Unit tests for the /usage output parser.
# Compiles UsageParser (Foundation only — no AppKit, no app launch) together
# with the test cases and runs them. No dependencies beyond the Swift compiler.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install Xcode Command Line Tools with:  xcode-select --install" >&2
  exit 1
fi

BUILD_DIR="$DIR/build"
mkdir -p "$BUILD_DIR"
BIN="$BUILD_DIR/UsageParserTests"

echo "Compiling parser tests..."
swiftc -O "$DIR/Sources/UsageParser.swift" "$DIR/Tests/UsageParserTests.swift" -o "$BIN"

echo "Running tests..."
"$BIN"
