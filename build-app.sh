#!/usr/bin/env bash
# Build a double-clickable Pomodoro.app from the SwiftPM binary.
# Usage: ./build-app.sh   →  produces ./Pomodoro.app
set -euo pipefail
cd "$(dirname "$0")"

APP="Pomodoro.app"
BIN_NAME="Pomodoro"

echo "▸ Compiling (release)…"
swift build -c release

BIN_PATH=".build/release/$BIN_NAME"

echo "Assembling ${APP} ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Pomodoro</string>
    <key>CFBundleDisplayName</key>     <string>Pomodoro</string>
    <key>CFBundleIdentifier</key>      <string>com.gjgaurav9.onscreen-pomodoro</string>
    <key>CFBundleExecutable</key>      <string>Pomodoro</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <!-- Agent app: no Dock icon, no menu bar — a pure floating overlay. -->
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

# Ad-hoc codesign so Gatekeeper/Spaces behaviour is stable on local machines.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Built $APP"
echo "  Run it:     open $APP"
echo "  Install it: cp -r $APP /Applications/"
