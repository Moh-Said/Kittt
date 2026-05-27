#!/bin/sh
# Render Kittt SwiftUI views to PNGs in build/snapshots/.
# Bypasses SwiftPM (no XCTest needed) by compiling all sources + snapshot-main.swift
# directly with swiftc.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p build/snapshots

# All Kittt sources except the @main app entry
SOURCES=$(find Sources/Kittt -name "*.swift" ! -name "KitttApp.swift")

echo "Compiling snapshot tool..."
swiftc -O -parse-as-library \
    $SOURCES \
    scripts/snapshot-main.swift \
    -o build/snapshot-tool

echo "Rendering..."
./build/snapshot-tool

echo
echo "Output: $ROOT/build/snapshots/"
ls -1 "$ROOT/build/snapshots/" 2>/dev/null || echo "(no files)"
