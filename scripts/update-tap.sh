#!/usr/bin/env bash
# Updates the Stagehand cask and formula in the sheatsley/tap Homebrew tap
# for a released version, checks them the way Homebrew's CI would, then commits
# (signed) and pushes the tap. Called by release.sh after the GitHub release is
# published, since the checks download the release. If a check fails, the tap is
# left unchanged: fix packaging/homebrew/ and run this script again by hand.
# Usage: scripts/update-tap.sh X.Y.Z <sha256 of Stagehand-X.Y.Z.zip>
#
# Optional environment override:
#   STAGEHAND_TAP_DIR   path to your clone of the tap (default: Homebrew's own clone)
set -euo pipefail

REPO="sheatsley/stagehand"
TAP="sheatsley/tap"

# Print an error and stop
die() { echo "error: $*" >&2; exit 1; }

# Work from the repository root and read the arguments
cd "$(dirname "$0")/.."
VERSION="${1:-}"
ZIP_SHA="${2:-}"
[ -n "$VERSION" ] && [ -n "$ZIP_SHA" ] || die "usage: scripts/update-tap.sh X.Y.Z <zip sha256>"

# Find the tap clone (a release must not silently skip it)
TAP_DIR="${STAGEHAND_TAP_DIR:-$(brew --repository "$TAP" 2>/dev/null || true)}"
[ -n "$TAP_DIR" ] && [ -d "$TAP_DIR/.git" ] || die "Homebrew tap not found (run: brew tap $TAP, or set STAGEHAND_TAP_DIR)"

# Bring the tap up to date, and refuse to build on a HEAD you didn't sign
git -C "$TAP_DIR" pull --ff-only --quiet
[ "$(git -C "$TAP_DIR" log -1 --format=%G?)" = "G" ] || die "the tap's HEAD is not signed by a trusted key; inspect $TAP_DIR before releasing"
[ -z "$(git -C "$TAP_DIR" status --porcelain)" ] || die "the tap has uncommitted changes; commit or discard them first"

# Hash the source tarball GitHub generates for the tag (the formula builds from it)
SRC_SHA="$(curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz" | shasum -a 256 | awk '{print $1}')"

# Fill in the cask and formula templates
mkdir -p "$TAP_DIR/Casks" "$TAP_DIR/Formula"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__ZIP_SHA256__/$ZIP_SHA/g" \
    packaging/homebrew/cask.rb > "$TAP_DIR/Casks/stagehand.rb"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__SRC_SHA256__/$SRC_SHA/g" \
    packaging/homebrew/formula.rb > "$TAP_DIR/Formula/stagehand.rb"

# Run the tap's checks (style, audit, livecheck); undo the edits if they fail
if ! "$TAP_DIR/scripts/check.sh"; then
    git -C "$TAP_DIR" checkout --quiet -- Casks Formula
    git -C "$TAP_DIR" clean --quiet -fd -- Casks Formula
    die "the tap's checks failed (see above); the tap was left unchanged. Fix the cause, then run: scripts/update-tap.sh $VERSION $ZIP_SHA"
fi

# Commit (signed, using Homebrew's commit message convention), confirm the signature, and push
git -C "$TAP_DIR" add Casks/stagehand.rb Formula/stagehand.rb
git -C "$TAP_DIR" commit --quiet --gpg-sign -m "stagehand $VERSION"
git -C "$TAP_DIR" verify-commit HEAD >/dev/null 2>&1 || die "the new tap commit's signature did not verify; not pushing"
git -C "$TAP_DIR" push --quiet

echo "Updated the tap to stagehand $VERSION"
