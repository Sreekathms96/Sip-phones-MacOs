#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-sip-phones}"
IDENTIFIER="${IDENTIFIER:-com.sipphones.softphone}"
VERSION="${VERSION:-1.0.0}"
EXPORT_PATH="${EXPORT_PATH:-$PWD/build/export}"
OUTPUT_PATH="${OUTPUT_PATH:-$PWD/build/$APP_NAME.pkg}"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ROOT_DIR="$PWD/build/pkg-root"

if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH"
  echo "Run Scripts/package-release.sh first."
  exit 1
fi

rm -rf "$ROOT_DIR"
mkdir -p "$ROOT_DIR/Applications"
cp -R "$APP_PATH" "$ROOT_DIR/Applications/"

if [ -n "${INSTALLER_SIGN_IDENTITY:-}" ]; then
  pkgbuild \
    --root "$ROOT_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    --sign "$INSTALLER_SIGN_IDENTITY" \
    "$OUTPUT_PATH"
else
  pkgbuild \
    --root "$ROOT_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    "$OUTPUT_PATH"
fi

echo "Created PKG at $OUTPUT_PATH"
