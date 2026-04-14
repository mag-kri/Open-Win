#!/bin/bash
set -euo pipefail

APP_NAME="BetterMac"
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
PKG_IDENTIFIER="com.bettermac.installer"
RELEASE_DIR="build-release"
PKG_ROOT="$RELEASE_DIR/pkg-root"
PKG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.pkg"
SCRIPT_DIR="packaging/scripts"
LAUNCHER_TEMPLATE="packaging/bin/bettermac"

echo "Building $APP_NAME app bundle..."
./build-app.sh

echo "Preparing installer payload..."
rm -rf "$PKG_ROOT" "$PKG_PATH"
mkdir -p "$PKG_ROOT/Applications" "$PKG_ROOT/usr/local/bin"

ditto "$APP_NAME.app" "$PKG_ROOT/Applications/$APP_NAME.app"
cp "$LAUNCHER_TEMPLATE" "$PKG_ROOT/usr/local/bin/bettermac"
chmod 755 "$PKG_ROOT/usr/local/bin/bettermac"

echo "Building installer package..."
pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$SCRIPT_DIR" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG_PATH"

echo ""
echo "$APP_NAME installer created successfully!"
echo "Location: $(pwd)/$PKG_PATH"
echo ""
echo "Installs:"
echo "  - /Applications/$APP_NAME.app"
echo "  - /usr/local/bin/bettermac"
