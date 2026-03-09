#!/bin/bash
# Claude Usage Widget — one-command installer
# Usage: curl -fsSL https://raw.githubusercontent.com/rishi-banerjee1/claude-usage-widget/main/install.sh | bash

set -e

APP_NAME="ClaudeUsage"
REPO="rishi-banerjee1/claude-usage-widget"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo ""
echo "  Claude Usage Widget — Installing..."
echo ""

# Get latest release download URL
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"browser_download_url".*\.zip"' \
  | head -1 \
  | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "  Error: Could not find a release. Check https://github.com/${REPO}/releases"
  exit 1
fi

# Download
echo "  Downloading from GitHub Releases..."
curl -fsSL -o "${TMP_DIR}/${APP_NAME}.zip" "$DOWNLOAD_URL"

# Unzip
echo "  Extracting..."
unzip -q "${TMP_DIR}/${APP_NAME}.zip" -d "$TMP_DIR"

# Remove old version if present
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "  Removing previous version..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Move to /Applications
echo "  Installing to ${INSTALL_DIR}..."
mv "${TMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

# Remove quarantine attribute so Gatekeeper doesn't block it
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo ""
echo "  Installed! Launching..."
echo ""
open "${INSTALL_DIR}/${APP_NAME}.app"

echo "  ✓ Claude Usage Widget is running."
echo "  → Right-click the widget to open Settings and enter your credentials."
echo ""
