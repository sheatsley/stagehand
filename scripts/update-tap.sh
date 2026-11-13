#!/usr/bin/env bash
# Updates the Stagehand cask and formula in the sheatsley/formulae Homebrew tap
# for a released version, then commits and pushes the tap. Called by
# release.sh; can also be run by hand. Skips quietly if the tap isn't cloned.
# Usage: scripts/update-tap.sh X.Y.Z <sha256 of Stagehand-X.Y.Z.zip>
#
# Optional environment override:
#   STAGEHAND_TAP_DIR   path to your clone of the tap (default: Homebrew's own clone)
set -euo pipefail

REPO="sheatsley/stagehand"

# Print an error and stop
die() { echo "error: $*" >&2; exit 1; }

# Work from the repository root and read the arguments
cd "$(dirname "$0")/.."
VERSION="${1:-}"
ZIP_SHA="${2:-}"
[ -n "$VERSION" ] && [ -n "$ZIP_SHA" ] || die "usage: scripts/update-tap.sh X.Y.Z <zip sha256>"

# Find the tap clone, or skip if there isn't one
TAP_DIR="${STAGEHAND_TAP_DIR:-$(brew --repository sheatsley/formulae 2>/dev/null || true)}"
if [ -z "$TAP_DIR" ] || [ ! -d "$TAP_DIR/.git" ]; then
    echo "Homebrew tap not found; skipping tap update (run: brew tap sheatsley/formulae)"
    exit 0
fi

# Bring the tap up to date before editing it
git -C "$TAP_DIR" pull --ff-only --quiet

# Hash the source tarball GitHub generates for the tag (the formula builds from it)
SRC_SHA="$(curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz" | shasum -a 256 | awk '{print $1}')"

# Fill in the cask and formula templates
mkdir -p "$TAP_DIR/Casks" "$TAP_DIR/Formula"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__ZIP_SHA256__/$ZIP_SHA/g" \
    packaging/homebrew/cask.rb > "$TAP_DIR/Casks/stagehand.rb"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__SRC_SHA256__/$SRC_SHA/g" \
    packaging/homebrew/formula.rb > "$TAP_DIR/Formula/stagehand.rb"

# Commit and push using Homebrew's commit message convention
git -C "$TAP_DIR" add Casks/stagehand.rb Formula/stagehand.rb
git -C "$TAP_DIR" commit --quiet -m "stagehand $VERSION"
git -C "$TAP_DIR" push --quiet

echo "Updated the tap to stagehand $VERSION"
