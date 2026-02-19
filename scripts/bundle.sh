#!/bin/bash
set -euo pipefail

APP_NAME="ClipboardWhere"
VERSION=$(grep 'static let version' Sources/ClipboardWhere/Constants.swift | sed 's/.*"\(.*\)".*/\1/')
OUTPUT_DIR="build"
BUILD_DIR=".build/release"
BUNDLE_DIR="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.dmg"
DMG_RW="${OUTPUT_DIR}/${APP_NAME}-rw.dmg"
DMG_MOUNT="/tmp/clipboardwhere-dmg-$$"

echo "==> Building ${APP_NAME} v${VERSION} (release)..."
swift build -c release

echo "==> Creating app bundle..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

sed -e "s/<string>1.0<\/string>/<string>${VERSION}<\/string>/" \
    "Resources/Info.plist" > "${CONTENTS_DIR}/Info.plist"

echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "==> Creating styled DMG..."
rm -f "$DMG_PATH" "$DMG_RW"
rm -f "${OUTPUT_DIR}"/${APP_NAME}-v*.dmg

# Create writable DMG
hdiutil create -size 50m -fs HFS+ -volname "$APP_NAME" "$DMG_RW"
mkdir -p "$DMG_MOUNT"
DEVICE=$(hdiutil attach "$DMG_RW" -mountpoint "$DMG_MOUNT" -nobrowse | head -1 | awk '{print $1}')
cp -R "$BUNDLE_DIR" "$DMG_MOUNT/"
ln -s /Applications "$DMG_MOUNT/Applications"

# Style the Finder window with drag-to-install layout
echo "==> Styling DMG window..."
osascript - "$DMG_MOUNT" <<'APPLESCRIPT' || echo "  (Finder styling skipped — AppleEvent timeout)"
on run argv
    set mountPath to POSIX file (item 1 of argv) as alias
    tell application "Finder"
        tell folder mountPath
            open
            delay 1
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 200, 720, 500}
            set theViewOptions to icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 128
            set position of item "ClipboardWhere.app" of container window to {130, 140}
            set position of item "Applications" of container window to {390, 140}
            delay 1
            close
        end tell
    end tell
end run
APPLESCRIPT

# Detach and convert to compressed DMG
sleep 1
sync
hdiutil detach "$DEVICE" -force
rmdir "$DMG_MOUNT" 2>/dev/null || true

for i in $(seq 1 10); do
    hdiutil info 2>/dev/null | grep -q "$DMG_RW" || break
    sleep 1
done

hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_RW"

echo ""
echo "================================================"
echo "  ${APP_NAME} v${VERSION} built successfully!"
echo ""
echo "  App:  ${BUNDLE_DIR}"
echo "  DMG:  ${DMG_PATH}"
echo ""
echo "  To install, open the DMG and drag to Applications."
echo "  To launch now:  open ${BUNDLE_DIR}"
echo "================================================"
