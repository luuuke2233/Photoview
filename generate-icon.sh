#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ICON="$PROJECT_DIR/icon/icon.png"
ICONSET_DIR="$PROJECT_DIR/icon.iconset"
OUTPUT_ICNS="${1:-$PROJECT_DIR/AppIcon.icns}"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Missing source icon: $SOURCE_ICON" >&2
    exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

make_icon() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$SOURCE_ICON" --out "$ICONSET_DIR/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$SOURCE_ICON" "$ICONSET_DIR/icon_512x512@2x.png"

cat > "$ICONSET_DIR/Contents.json" <<'EOF'
{
  "images" : [
    { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "Generated icon at $OUTPUT_ICNS"
