#!/bin/bash
set -euo pipefail

# record-demo.sh — Record a demo GIF of the Claude Usage Widget
# Prerequisites: ffmpeg (brew install ffmpeg)
# Output: assets/demo.gif

APP_NAME="ClaudeUsage"
OUTPUT_DIR="assets"
MOV_FILE="/tmp/claude-widget-demo.mov"
GIF_FILE="${OUTPUT_DIR}/demo.gif"
PALETTE_FILE="/tmp/claude-widget-palette.png"

RECORD_SECONDS=12
PADDING=40

# --- Dependency check ---
if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Ensure widget is running ---
if ! pgrep -x "$APP_NAME" >/dev/null; then
    echo "Widget not running. Launching..."
    if [ -d "/Applications/${APP_NAME}.app" ]; then
        open "/Applications/${APP_NAME}.app"
    elif [ -d "build/${APP_NAME}.app" ]; then
        open "build/${APP_NAME}.app"
    else
        echo "Error: Cannot find ${APP_NAME}.app. Run ./build.sh first."
        exit 1
    fi
    sleep 3
fi

# --- Get screen height for coordinate conversion ---
SCREEN_H=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 Resolution | awk '{print $4}')
if [ -z "$SCREEN_H" ]; then
    echo "Error: Could not detect screen resolution"
    exit 1
fi

# --- Get widget window position from UserDefaults ---
POS_X=$(defaults read com.claude.usage widgetPositionX 2>/dev/null | cut -d. -f1 || echo "")
POS_Y=$(defaults read com.claude.usage widgetPositionY 2>/dev/null | cut -d. -f1 || echo "")
IS_COMPACT=$(defaults read com.claude.usage widgetCompactMode 2>/dev/null || echo "0")

if [ "$IS_COMPACT" = "1" ]; then
    W_WIDTH=76
    W_HEIGHT=76
else
    W_WIDTH=140
    W_HEIGHT=170
fi

if [ -z "$POS_X" ] || [ -z "$POS_Y" ]; then
    echo "Warning: Could not read widget position from defaults."
    echo "Using fallback: bottom-right corner."
    SCREEN_W=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 Resolution | awk '{print $2}')
    POS_X=$((SCREEN_W - W_WIDTH - 20))
    POS_Y=$((W_HEIGHT + 20))
fi

# --- Convert AppKit coords (origin bottom-left) to screencapture (origin top-left) ---
CAPTURE_X=$((POS_X - PADDING))
CAPTURE_Y=$((SCREEN_H - POS_Y - W_HEIGHT - PADDING))
CAPTURE_W=$((W_WIDTH + PADDING * 2))
CAPTURE_H=$((W_HEIGHT + PADDING * 2))

# Clamp to screen bounds
[ "$CAPTURE_X" -lt 0 ] && CAPTURE_X=0
[ "$CAPTURE_Y" -lt 0 ] && CAPTURE_Y=0

echo ""
echo "Recording widget at (${CAPTURE_X}, ${CAPTURE_Y}) ${CAPTURE_W}x${CAPTURE_H}"
echo "Duration: ${RECORD_SECONDS}s"
echo ""
echo "TIP: During recording, try these interactions:"
echo "  1. Watch the widget update (auto-refreshes every 30s)"
echo "  2. Double-click to toggle compact mode"
echo "  3. Right-click to show context menu"
echo ""
echo "Recording starts in 3 seconds..."
sleep 3

# --- Record screen region ---
screencapture -v -V "$RECORD_SECONDS" -R "${CAPTURE_X},${CAPTURE_Y},${CAPTURE_W},${CAPTURE_H}" "$MOV_FILE"

if [ ! -f "$MOV_FILE" ]; then
    echo "Error: Recording failed — no output file"
    exit 1
fi

echo "Recording complete. Converting to GIF..."

# --- Two-pass ffmpeg: palette generation + GIF creation ---
# Pass 1: Generate optimal 256-color palette from video frames
ffmpeg -y -i "$MOV_FILE" \
    -vf "fps=10,scale=${CAPTURE_W}:-1:flags=lanczos,palettegen=stats_mode=diff" \
    "$PALETTE_FILE" 2>/dev/null

# Pass 2: Apply palette for high-quality GIF
ffmpeg -y -i "$MOV_FILE" -i "$PALETTE_FILE" \
    -lavfi "fps=10,scale=${CAPTURE_W}:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    "$GIF_FILE" 2>/dev/null

# --- Cleanup ---
rm -f "$MOV_FILE" "$PALETTE_FILE"

# --- Report ---
GIF_SIZE=$(ls -lh "$GIF_FILE" | awk '{print $5}')
echo ""
echo "Demo GIF created: ${GIF_FILE} (${GIF_SIZE})"
echo ""
if [ "$(stat -f%z "$GIF_FILE")" -gt 5242880 ]; then
    echo "Warning: GIF is over 5MB. Consider reducing RECORD_SECONDS or adjusting fps."
fi
