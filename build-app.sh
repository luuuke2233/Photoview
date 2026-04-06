#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/PhotoView-beta.app"
ICON_PNG="$PROJECT_DIR/icon.png"

echo "=== Building PhotoView Beta ==="
swift build -c release --package-path "$PROJECT_DIR"

echo "=== Creating .app bundle ==="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/.build/release/PhotoView" "$APP_DIR/Contents/MacOS/PhotoView"

if [ -f "$ICON_PNG" ]; then
    echo "=== Creating icon from icon.png ==="
    ICONSET_DIR=$(mktemp -d)/PhotoviewIcon.iconset
    mkdir -p "$ICONSET_DIR"
    
    for size in 16 32 64 128 256 512 1024; do
        sips -z $size $size "$ICON_PNG" --setProperty format png --out "$ICONSET_DIR/icon_${size}x${size}.png" > /dev/null 2>&1
        if [ $size -lt 1024 ]; then
            sips -z $((size*2)) $((size*2)) "$ICON_PNG" --setProperty format png --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" > /dev/null 2>&1
        fi
    done
    
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
fi

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PhotoView</string>
    <key>CFBundleDisplayName</key>
    <string>PhotoView Beta</string>
    <key>CFBundleIdentifier</key>
    <string>com.photoview.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.4-beta</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.4-beta</string>
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

echo "=== Done! Beta app created at $APP_DIR ==="
