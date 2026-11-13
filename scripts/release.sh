#!/usr/bin/env bash
# Cuts a Stagehand release from your Mac, doing locally what a CI release job
# would do: checks the repo is clean and in sync with GitHub, builds the app,
# zips it, makes a signed tag, publishes a GitHub release with the zip attached
# and the matching CHANGELOG.md section as notes, then updates the Homebrew tap.
# Usage: scripts/release.sh X.Y.Z   (or: make release VERSION=X.Y.Z)
set -euo pipefail

REPO="sheatsley/stagehand"
NAME="Stagehand"

# Print an error and stop
die() { echo "error: $*" >&2; exit 1; }

# Work from the repository root
cd "$(dirname "$0")/.."

# Validate the version argument
VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: scripts/release.sh X.Y.Z"
TAG="v$VERSION"

# Check the GitHub CLI is installed and signed in
command -v gh >/dev/null || die "the GitHub CLI is required (brew install gh)"
gh auth status >/dev/null 2>&1 || die "sign in to GitHub first (gh auth login)"

# Check the repo is on main, clean, in sync with GitHub, and the tag is new
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || die "releases are cut from main"
[ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes"
git fetch --quiet --tags origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main isn't in sync with origin/main (push or pull first)"
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "tag $TAG already exists"

# Pull this version's release notes out of CHANGELOG.md
NOTES="$(awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/      { exit }
    /^\[[^]]+\]: /         { next }
    found                  { print }
' CHANGELOG.md)"
[ -n "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ] || die "add a '## [$VERSION]' section to CHANGELOG.md first"

# Build and zip the app (ditto keeps the bundle's metadata intact)
STAGEHAND_VERSION="$VERSION" scripts/build.sh
ZIP="build/$NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/$NAME.app" "$ZIP"
ZIP_SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

# Tag the commit with a signed tag, confirm the signature, and push it (only after the build succeeded)
git tag --sign "$TAG" -m "$NAME $VERSION"
git tag --verify "$TAG" >/dev/null 2>&1 || { git tag --delete "$TAG" >/dev/null; die "the signature on tag $TAG did not verify; tag removed, nothing pushed"; }
git push --quiet origin "$TAG"

# Publish the GitHub release with the zip attached
gh release create "$TAG" "$ZIP" \
    --repo "$REPO" \
    --title "$NAME $VERSION" \
    --notes "$NOTES" \
    --verify-tag

# Point the Homebrew cask and formula at the new release
scripts/update-tap.sh "$VERSION" "$ZIP_SHA"

echo "Released $NAME $VERSION: https://github.com/$REPO/releases/tag/$TAG"
