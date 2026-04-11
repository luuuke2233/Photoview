#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$PROJECT_DIR/.beta-version"
BUILD_DIR="$PROJECT_DIR/.build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
CLANG_CACHE_DIR="$BUILD_DIR/clang-module-cache"
ICNS_PATH="$PROJECT_DIR/AppIcon.icns"

usage() {
    cat <<'EOF'
Usage:
  ./build-app.sh              Increment beta number and build a beta app
  ./build-app.sh --major      Increment base version and reset beta to 1
  ./build-app.sh --current    Build using the current stored version without incrementing
EOF
}

if [ ! -f "$VERSION_FILE" ]; then
    cat > "$VERSION_FILE" <<'EOF'
BASE_VERSION=1.5.6
BETA_NUMBER=0
EOF
fi

source "$VERSION_FILE"

MODE="increment-beta"
case "${1:-}" in
    "")
        ;;
    --major)
        MODE="major"
        ;;
    --current)
        MODE="current"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac

increment_base_version() {
    local version="$1"
    IFS='.' read -r major minor patch <<< "$version"
    patch=$((patch + 1))
    printf "%s.%s.%s" "$major" "$minor" "$patch"
}

case "$MODE" in
    major)
        BASE_VERSION="$(increment_base_version "$BASE_VERSION")"
        BETA_NUMBER=1
        ;;
    increment-beta)
        BETA_NUMBER=$((BETA_NUMBER + 1))
        ;;
    current)
        if [ "$BETA_NUMBER" -le 0 ]; then
            BETA_NUMBER=1
        fi
        ;;
esac

cat > "$VERSION_FILE" <<EOF
BASE_VERSION=$BASE_VERSION
BETA_NUMBER=$BETA_NUMBER
EOF

BETA_VERSION="${BASE_VERSION}-beta${BETA_NUMBER}"
APP_NAME="PhotoView-${BETA_VERSION}.app"
APP_DIR="$PROJECT_DIR/$APP_NAME"

echo "=== Building PhotoView $BETA_VERSION ==="
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"
env SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR" \
    CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
    swift build -c release --package-path "$PROJECT_DIR"

echo "=== Removing previous beta apps ==="
find "$PROJECT_DIR" -maxdepth 1 -type d -name 'PhotoView-*-beta*.app' ! -name "$APP_NAME" -exec rm -rf {} +

echo "=== Generating icon from icon/icon.png ==="
"$PROJECT_DIR/generate-icon.sh" "$ICNS_PATH"

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
    <string>PhotoView Beta</string>
    <key>CFBundleDisplayName</key>
    <string>PhotoView Beta</string>
    <key>CFBundleIdentifier</key>
    <string>com.photoview.app</string>
    <key>CFBundleVersion</key>
    <string>${BETA_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${BETA_VERSION}</string>
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
