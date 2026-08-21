#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TossNote"
BUNDLE_ID="com.tossnote.app"
MIN_SYSTEM_VERSION="13.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"

swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
BUILD_RESOURCES="$BUILD_DIR/TossNote_TossNote.bundle"

rm -rf "$APP_BUNDLE"
rm -f "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_MACOS/$APP_NAME"
cp -R "$BUILD_RESOURCES" "$APP_CONTENTS/Resources/"
cp "$ROOT_DIR/Sources/TossNote/Resources/TossNote.icns" "$APP_CONTENTS/Resources/TossNote.icns"
chmod +x "$APP_MACOS/$APP_NAME"

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>TossNote.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# This is ad-hoc signing only: it makes the bundle internally consistent but
# does not replace a Developer ID signature or Apple notarization.
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "$DMG_PATH"
