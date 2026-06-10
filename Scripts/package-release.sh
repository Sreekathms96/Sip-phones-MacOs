#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-sip-phones}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$PWD/build/$SCHEME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$PWD/build/export}"

xcodebuild archive \
  -project sip-phones.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist

echo "Exported app to $EXPORT_PATH"
