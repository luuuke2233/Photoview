#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/PhotoView.app"
ICON_DIR="$PROJECT_DIR/icon.iconset"

BETA_VERSION="1.5.4-beta11"

echo "=== Building PhotoView ==="
swift build -c release --package-path "$PROJECT_DIR"

echo "=== Creating .app bundle ==="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/.build/release/PhotoView" "$APP_DIR/Contents/MacOS/PhotoView"

if [ -d "$ICON_DIR" ]; then
    echo "=== Creating icon from icon.iconset ==="
    iconutil -c icns "$ICON_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
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
    <string>BETA_VERSION_PLACEHOLDER</string>
    <key>CFBundleShortVersionString</key>
    <string>BETA_VERSION_PLACEHOLDER</string>
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

sed -i '' "s/BETA_VERSION_PLACEHOLDER/$BETA_VERSION/g" "$APP_DIR/Contents/Info.plist"

echo "=== Done! App created at $APP_DIR ==="
