#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building release binary..."
swift build -c release --arch arm64

APP="$ROOT/build/Kittt.app"
BIN_SRC="$ROOT/.build/arm64-apple-macosx/release/Kittt"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_SRC" "$APP/Contents/MacOS/Kittt"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

COUNTER_FILE="$ROOT/.build-number"
BUILD_NUMBER=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
BUILD_NUMBER=$((BUILD_NUMBER + 1))
echo "$BUILD_NUMBER" > "$COUNTER_FILE"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
echo "Build number: $BUILD_NUMBER"

strip -x "$APP/Contents/MacOS/Kittt" || true

echo "Ad-hoc signing..."
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run with: open '$APP'"
