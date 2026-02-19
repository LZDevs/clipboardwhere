#!/bin/bash
set -euo pipefail

APP_NAME="ClipboardWhere"
VERSION=$(grep 'static let version' Sources/ClipboardWhere/Constants.swift | sed 's/.*"\(.*\)".*/\1/')
OUTPUT_DIR="build"
BUILD_DIR=".build/release"
BUNDLE_DIR="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
DMG_DIR="${OUTPUT_DIR}/dmg"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.dmg"

echo "==> Building ${APP_NAME} v${VERSION} (release)..."
swift build -c release

echo "==> Creating app bundle..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Update version in Info.plist and copy
sed -e "s/<string>1.0<\/string>/<string>${VERSION}<\/string>/" \
    "Resources/Info.plist" > "${CONTENTS_DIR}/Info.plist"

# Ad-hoc code sign so macOS can identify the app for permissions
echo "==> Code signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "==> Creating DMG..."
rm -rf "$DMG_DIR"
rm -f "${OUTPUT_DIR}"/${APP_NAME}-v*.dmg
mkdir -p "$DMG_DIR"

cp -R "$BUNDLE_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "${APP_NAME} v${VERSION}" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "Done! ${APP_NAME} v${VERSION}"
echo "  App: ${BUNDLE_DIR}"
echo "  DMG: ${DMG_PATH}"
