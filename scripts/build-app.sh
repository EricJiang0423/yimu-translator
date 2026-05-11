#!/usr/bin/env bash
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ── Compile in temp dir (avoids xattr pollution from project) ─

echo "=== Building ==="
swiftc -swift-version 6 -parse-as-library -emit-library -emit-module \
  -module-name GameTranslatorCore \
  "$PROJECT/Sources/GameTranslatorCore/"*.swift \
  -emit-module-path "$TMPDIR/GameTranslatorCore.swiftmodule" \
  -o "$TMPDIR/libGameTranslatorCore.dylib" \
  -framework CryptoKit \
  -Xlinker -install_name -Xlinker "@rpath/libGameTranslatorCore.dylib"

swiftc -swift-version 6 -I "$TMPDIR" -L "$TMPDIR" -lGameTranslatorCore \
  "$PROJECT/Sources/GameTranslatorApp/"*.swift \
  -o "$TMPDIR/game-translator" \
  -framework AppKit -framework CoreGraphics -framework CryptoKit \
  -framework Vision -framework ScreenCaptureKit \
  -Xlinker -rpath -Xlinker "@executable_path"

# ── Assemble .app bundle ─────────────────────────────────

echo "=== Assembling app bundle ==="
APP_NAME="译幕"
APP_DIR="$TMPDIR/$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$TMPDIR/game-translator" "$APP_DIR/Contents/MacOS/"
cp "$TMPDIR/libGameTranslatorCore.dylib" "$APP_DIR/Contents/MacOS/"
cp "$TMPDIR/GameTranslatorCore.swiftmodule" "$APP_DIR/Contents/MacOS/"
cp "$TMPDIR/GameTranslatorCore.swiftdoc" "$APP_DIR/Contents/MacOS/" 2>/dev/null || true
cp "$TMPDIR/GameTranslatorCore.swiftsourceinfo" "$APP_DIR/Contents/MacOS/" 2>/dev/null || true
cp "$TMPDIR/GameTranslatorCore.abi.json" "$APP_DIR/Contents/MacOS/" 2>/dev/null || true

# Plist via cat to strip any xattrs
cat "$PROJECT/Resources/Info.plist" > "$APP_DIR/Contents/Info.plist"

# ── App icon ─────────────────────────────────────────────

if [ -f "$PROJECT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "Warning: Resources/AppIcon.icns not found, skipping icon."
fi
if [ -f "$PROJECT/Resources/menubar.png" ]; then
    cp "$PROJECT/Resources/menubar.png" "$APP_DIR/Contents/Resources/menubar.png"
fi
if [ -f "$PROJECT/Resources/menubar@2x.png" ]; then
    cp "$PROJECT/Resources/menubar@2x.png" "$APP_DIR/Contents/Resources/menubar@2x.png"
fi

# ── Code sign ────────────────────────────────────────────

echo "=== Code signing ==="
codesign --force --deep --sign - \
  --entitlements "$PROJECT/Resources/GameTranslator.entitlements" \
  "$APP_DIR"

# ── Deliver ──────────────────────────────────────────────

FINAL_DIR="$PROJECT/.build/app"
rm -rf "$FINAL_DIR"
mkdir -p "$FINAL_DIR"
ditto "$APP_DIR" "$FINAL_DIR/$APP_NAME.app"

# ── DMG ──────────────────────────────────────────────────

echo ""
echo "=== Creating DMG ==="
DMG_STAGING="$(mktemp -d)"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

DMG_FILE="$FINAL_DIR/$APP_NAME.dmg"
rm -f "$DMG_FILE"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DMG_FILE" > /dev/null

# Layout: app left, Applications alias right
hdiutil attach "$DMG_FILE" -noautoopen -quiet -mountpoint /Volumes/GameTranslatorDMG 2>/dev/null || true
# Skip Finder layout if DMG attachment fails - the DMG still works
if [ -d "/Volumes/GameTranslatorDMG" ]; then
  osascript - <<'APPLESCRIPT' 2>/dev/null || true
tell application "Finder"
  set dmgVolume to disk "译幕"
  open dmgVolume
  set toolbar visible of container window of dmgVolume to false
  set statusbar visible of container window of dmgVolume to false
  set bounds of container window of dmgVolume to {100, 100, 520, 360}
  set position of item "译幕.app" of container window of dmgVolume to {100, 120}
  set position of item "Applications" of container window of dmgVolume to {320, 120}
  close container window of dmgVolume
end tell
APPLESCRIPT
  hdiutil detach /Volumes/GameTranslatorDMG -quiet 2>/dev/null || true
fi
rm -rf "$DMG_STAGING"

echo ""
echo "✅  $FINAL_DIR/$APP_NAME.app"
echo "📦  $DMG_FILE"
echo ""
echo "Run:  open \"$FINAL_DIR/$APP_NAME.app\""
echo "DMG:  open \"$DMG_FILE\""
