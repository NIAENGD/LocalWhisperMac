#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalWhisperMac"
BUNDLE_ID="com.localwhispermac.app"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
RESOURCE_SRC="Sources/LocalWhisperMac/Resources"
ICON_NAME="AppIcon"
ICON_FILE="icon.png"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [ -d "$RESOURCE_SRC" ]; then
  cp -R "$RESOURCE_SRC"/* "$APP_DIR/Contents/Resources/"
fi

ICON_SOURCE_PNG="$ICON_FILE"
if [ ! -f "$ICON_SOURCE_PNG" ]; then
  echo "Missing icon source file: $ICON_SOURCE_PNG" >&2
  exit 1
fi

cp "$ICON_SOURCE_PNG" "$APP_DIR/Contents/Resources/${ICON_NAME}.png"

if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  ICONSET_DIR="$APP_DIR/Contents/Resources/${ICON_NAME}.iconset"
  mkdir -p "$ICONSET_DIR"

  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/${ICON_NAME}.icns"
  rm -rf "$ICONSET_DIR"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
PLIST

echo "Built app bundle: $APP_DIR"
