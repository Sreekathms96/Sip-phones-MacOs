#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-sip-phones}"
VOLUME_NAME="${VOLUME_NAME:-SIP Phones}"
EXPORT_PATH="${EXPORT_PATH:-$PWD/build/export}"
OUTPUT_PATH="${OUTPUT_PATH:-$PWD/build/$APP_NAME.dmg}"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
STAGING_DIR="$PWD/build/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH"
  echo "Run Scripts/package-release.sh first."
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH"

echo "Created DMG at $OUTPUT_PATH"
