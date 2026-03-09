#!/bin/bash
set -euo pipefail

# release.sh — Build, package, and publish a new GitHub release
# Usage: ./release.sh [--dry-run]

APP_NAME="ClaudeUsage"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}.app.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"
REPO="rishi-banerjee1/claude-usage-widget"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# 1. Read version
VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
    echo "Error: VERSION file missing or empty"
    exit 1
fi
TAG="v${VERSION}"
echo "Releasing ${TAG}..."

# 2. Check gh CLI
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: gh CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

# 3. Check tag collision
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "Error: Release ${TAG} already exists. Bump VERSION first."
    exit 1
fi

# 4. Build
echo "Building..."
./build.sh

# 5. Package ZIP
echo "Packaging ZIP..."
rm -f "$ZIP_PATH"
(cd "$BUILD_DIR" && zip -r "$ZIP_NAME" "${APP_NAME}.app")

# 6. Compute SHA256
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo ""
echo "========================================="
echo "  SHA256: ${SHA256}"
echo "========================================="
echo ""

# 7. Extract release notes from CHANGELOG.md
NOTES=$(sed -n "/^## \[${VERSION}\]/,/^---/{/^## \[${VERSION}\]/d;/^---/d;p;}" CHANGELOG.md)
if [ -z "$NOTES" ]; then
    NOTES="Release ${TAG}"
fi

# 8. Create release + upload asset
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create release ${TAG} and upload ${ZIP_PATH}"
    echo ""
    echo "Release notes:"
    echo "$NOTES"
else
    echo "Creating GitHub release ${TAG}..."
    echo "$NOTES" | gh release create "$TAG" "$ZIP_PATH" \
        --repo "$REPO" \
        --title "${TAG}" \
        --notes-file -

    echo ""
    echo "Release published: https://github.com/${REPO}/releases/tag/${TAG}"
fi

# 9. Homebrew cask update instructions
echo ""
echo "To update Homebrew cask:"
echo "  1. Edit Casks/claude-usage-widget.rb in homebrew-ai-tools"
echo "  2. Set version \"${VERSION}\""
echo "  3. Set sha256 \"${SHA256}\""
echo "  4. Commit and push"
