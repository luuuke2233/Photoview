#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
CLANG_CACHE_DIR="$BUILD_DIR/clang-module-cache"
VERSION="1.5.6"
APP_NAME="PhotoView-${VERSION}.app"
APP_DIR="$PROJECT_DIR/$APP_NAME"
ICNS_PATH="$PROJECT_DIR/AppIcon.icns"

echo "=== Building PhotoView ${VERSION} ==="
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"
env SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR" \
    CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
    swift build -c release --package-path "$PROJECT_DIR"

echo "=== Generating app icon from icon/icon.png ==="
"$PROJECT_DIR/generate-icon.sh" "$ICNS_PATH"

echo "=== Removing previous formal app ==="
find "$PROJECT_DIR" -maxdepth 1 -type d -name 'PhotoView-*.app' ! -name "$APP_NAME" -exec rm -rf {} +

echo "=== Creating .app bundle ==="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/.build/release/PhotoView" "$APP_DIR/Contents/MacOS/PhotoView"
cp "$ICNS_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PhotoView</string>
    <key>CFBundleDisplayName</key>
    <string>PhotoView</string>
    <key>CFBundleIdentifier</key>
    <string>com.photoview.app</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>PhotoView</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "=== Done! App created at $APP_DIR ==="
