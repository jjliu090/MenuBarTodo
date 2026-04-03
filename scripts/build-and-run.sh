#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MenuBarTodo"
APP_BUNDLE="$PROJECT_DIR/build/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=== MenuBarTodo Build Script ==="
echo ""

# Step 1: Build release binary
echo "[1/4] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -1
BINARY="$PROJECT_DIR/.build/release/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Build failed, binary not found."
    exit 1
fi

BINARY_SIZE=$(ls -lh "$BINARY" | awk '{print $5}')
echo "       Binary size: $BINARY_SIZE"

# Step 2: Create .app bundle
echo "[2/4] Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS/$APP_NAME"

# Create Info.plist (no sandbox for non-developer)
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MenuBarTodo</string>
    <key>CFBundleIdentifier</key>
    <string>com.menubartodo.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MenuBarTodo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 MenuBarTodo. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "       Bundle: $APP_BUNDLE"

# Step 3: Ad-hoc code sign (no developer account needed)
echo "[3/4] Ad-hoc code signing..."
codesign --force --sign - "$APP_BUNDLE" 2>&1
echo "       Signed with ad-hoc identity"

# Step 4: Launch
echo "[4/4] Launching..."
echo ""

# Kill existing instance if running
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
sleep 0.5

open "$APP_BUNDLE"

echo "=== MenuBarTodo is running ==="
echo ""
echo "Look for the ✓ icon in your menu bar (top-right of screen)."
echo "Global hotkey: Cmd+Shift+T"
echo ""
echo "To stop:  pkill MenuBarTodo"
echo "To start: open $APP_BUNDLE"
echo ""

# Wait and show memory usage
sleep 2
PID=$(pgrep -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" | head -1)
if [ -n "$PID" ]; then
    RSS_KB=$(ps -o rss= -p "$PID" | tr -d ' ')
    RSS_MB=$(echo "scale=1; $RSS_KB / 1024" | bc)
    echo "Memory (idle RSS): ${RSS_MB} MB  (target: < 8 MB)"
fi
