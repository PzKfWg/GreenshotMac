#!/bin/bash
set -euo pipefail

APP_NAME="GreenshotMac"
BUILD_CONFIG="${1:-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Sources/GreenshotMac/Resources"
INSTALL_DIR="/Applications"

# Build
echo "Building ($BUILD_CONFIG)..."
cd "$PROJECT_DIR"
if [ "$BUILD_CONFIG" = "debug" ]; then
    swift build
    BUILD_DIR=".build/debug"
else
    swift build -c release
    BUILD_DIR=".build/release"
fi

# Create .app bundle structure
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found, bundle will have no custom icon"
fi

# Ad-hoc code signing with entitlements
ENTITLEMENTS="$PROJECT_DIR/scripts/entitlements.plist"
echo "Signing (ad-hoc)..."
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

echo "Bundle created at: $APP_BUNDLE"

# Install to /Applications
echo "Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo "Run with: open $INSTALL_DIR/$APP_NAME.app"
