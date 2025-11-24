#!/bin/bash

# Show Latest Screenshot - Helper script for Claude Code
# Usage: Run this script or use the command to view the latest screenshot

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
LATEST="$SCREENSHOT_DIR/latest.png"

if [ -f "$LATEST" ]; then
    echo "Latest screenshot: $LATEST"
    echo "File size: $(du -h "$LATEST" | cut -f1)"
    echo "Modified: $(stat -c %y "$LATEST" | cut -d. -f1)"
    echo ""
    echo "To view in Claude Code, tell Claude:"
    echo "  'Read ~/Pictures/Screenshots/latest.png'"
    echo ""
    echo "Or copy the path to clipboard:"
    wl-copy "$LATEST"
    echo "✅ Path copied to clipboard!"
else
    echo "❌ No screenshot found at $LATEST"
    echo "Take a screenshot first with your keybind"
    exit 1
fi
