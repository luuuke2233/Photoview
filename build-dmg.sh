#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.5.6"
APP_NAME="PhotoView-${VERSION}.app"
APP_PATH="$PROJECT_DIR/$APP_NAME"
DMG_NAME="PhotoView-${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
STAGING_DIR="$PROJECT_DIR/.dmg-staging"

if [ ! -d "$APP_PATH" ]; then
    "$PROJECT_DIR/build-release.sh"
fi

echo "=== Preparing DMG staging directory ==="
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "=== Creating DMG ==="
rm -f "$DMG_PATH"
hdiutil create \
    -volname "PhotoView ${VERSION}" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"
echo "=== Done! DMG created at $DMG_PATH ==="
