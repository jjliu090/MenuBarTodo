#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MenuBarTodo"
APP_BUNDLE="$PROJECT_DIR/build/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"

echo "=== MenuBarTodo Install ==="

# 1. 关闭正在运行的旧版本
if pgrep -f "${APP_NAME}.app" > /dev/null 2>&1; then
    echo "[1/4] Stopping running instance..."
    pkill -f "${APP_NAME}.app" 2>/dev/null || true
    sleep 0.5
else
    echo "[1/4] No running instance."
fi

# 2. 编译 Release
echo "[2/4] Building..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -1

# 3. 打包 .app
echo "[3/4] Packaging..."
BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
CONTENTS="$APP_BUNDLE/Contents"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"
echo -n "APPL????" > "$CONTENTS/PkgInfo"
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
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP_BUNDLE" 2>/dev/null

# 4. 覆盖安装并启动
echo "[4/4] Installing to /Applications..."
rm -rf "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"
open "$INSTALL_PATH"

sleep 1
echo ""
echo "=== Done! MenuBarTodo updated and running ==="
