#!/usr/bin/env bash
# Builds Stagehand.app: compiles the Swift package in release mode, assembles
# the .app bundle, fills in Info.plist (version, commit hash, copyright), adds
# the app icon if Resources/AppIcon.png exists, and ad-hoc signs the result.
# Output: build/Stagehand.app. Usage: scripts/build.sh
#
# Optional environment overrides (used by the release script and the Homebrew formula):
#   STAGEHAND_VERSION   version string (default: latest git tag without the "v", else 0.0.0)
#   STAGEHAND_COMMIT    build identifier (default: short commit hash, plus -dirty if modified)
#   SWIFT_BUILD_FLAGS   extra flags for `swift build` (Homebrew passes --disable-sandbox)
set -euo pipefail

# App metadata
NAME="Stagehand"
BUNDLE_ID="me.sheatsley.stagehand"
DEVELOPER="Ryan Sheatsley"
WEBSITE="https://github.com/sheatsley/stagehand"
LICENSE_NAME="MIT License"

# Work from the repository root
cd "$(dirname "$0")/.."

# Work out the version: explicit override, else the latest tag, else 0.0.0
VERSION="${STAGEHAND_VERSION:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    VERSION="${VERSION#v}"
    VERSION="${VERSION:-0.0.0}"
fi

# Work out the build identifier: explicit override, else the commit hash (-dirty if modified)
COMMIT="${STAGEHAND_COMMIT:-}"
if [ -z "$COMMIT" ]; then
    COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    if [ "$COMMIT" != "unknown" ] && ! git diff --quiet HEAD 2>/dev/null; then
        COMMIT="$COMMIT-dirty"
    fi
fi
COPYRIGHT="© $(date +%Y) $DEVELOPER. Released under the $LICENSE_NAME."

# Compile the release binary for Apple silicon
# shellcheck disable=SC2086  # SWIFT_BUILD_FLAGS is intentionally word-split
swift build -c release --arch arm64 ${SWIFT_BUILD_FLAGS:-}
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c release --arch arm64 ${SWIFT_BUILD_FLAGS:-} --show-bin-path)"

# Assemble a fresh bundle
APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"

# Fill in the Info.plist template
sed -e "s|__NAME__|$NAME|g" \
    -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
    -e "s|__VERSION__|$VERSION|g" \
    -e "s|__COMMIT__|$COMMIT|g" \
    -e "s|__DEVELOPER__|$DEVELOPER|g" \
    -e "s|__WEBSITE__|$WEBSITE|g" \
    -e "s|__COPYRIGHT__|$COPYRIGHT|g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"

# Convert Resources/AppIcon.png (1024x1024) into an .icns icon, if present
if [ -f Resources/AppIcon.png ]; then
    ICONSET="build/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    plutil -replace CFBundleIconFile -string AppIcon "$APP/Contents/Info.plist"
fi

# Ad-hoc sign (Apple silicon won't run unsigned arm64 code; this is not a Developer ID signature)
codesign --force --sign - "$APP"

echo "Built $APP ($VERSION, $COMMIT)"
