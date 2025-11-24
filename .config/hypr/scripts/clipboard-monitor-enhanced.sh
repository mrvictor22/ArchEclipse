#!/bin/bash
# Enhanced Clipboard Monitor for Claude Code Integration
# Automatically saves images and provides smart notifications

# Configuration
CLAUDE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$CLAUDE_DIR/latest.png"
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
LOG_FILE="/tmp/clipboard-monitor.log"

# Ensure directories exist
mkdir -p "$CLAUDE_DIR"

# Simple lock to prevent concurrent executions
LOCK_FILE="/tmp/clipboard-monitor-exec.lock"

# Try to acquire lock (non-blocking)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] SKIP: Already running" >> /tmp/clip-count.log
    exit 0
fi

# Clean up lock on exit
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

echo "[$(date '+%H:%M:%S')] EXEC" >> /tmp/clip-count.log

# Function to check if Windsurf is focused
is_windsurf_focused() {
    focused_class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')
    [[ "${focused_class,,}" == *"windsurf"* ]]
}

# Check what types are available in the clipboard
available_types=$(wl-paste --list-types 2>/dev/null)

# Check if there's an image in the clipboard
if echo "$available_types" | grep -q "^image/"; then
    # Image detected
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Save to multiple locations
    image_path="/tmp/clipboard_image_${timestamp}.png"
    claude_image="$CLAUDE_DIR/clipboard_${timestamp}.png"

    # Save the image
    if wl-paste --type image/png > "$image_path" 2>/dev/null; then
        file_size=$(stat -c%s "$image_path" 2>/dev/null || echo 0)

        if [ "$file_size" -gt 0 ]; then
            # Copy to Claude directory
            cp "$image_path" "$claude_image"

            # Update the latest symlink
            ln -sf "$claude_image" "$LATEST_IMAGE"

            # Also save to Screenshots for easy access
            cp "$image_path" "$SCREENSHOT_DIR/clipboard_latest.png" 2>/dev/null

            # Check if Windsurf is focused for smart notification
            if is_windsurf_focused; then
                # Windsurf is focused - show special notification
                notify-send "Claude Code: Image Ready!" \
                    "Image saved for Claude\n\nPress Super+Alt+V to copy path\nThen Ctrl+V in Claude chat" \
                    -i "$image_path" \
                    -t 6000 \
                    -u normal \
                    -a "Claude Helper"

                echo "[$(date '+%H:%M:%S')] IMAGE_WINDSURF: $claude_image" >> /tmp/clip-count.log
            else
                # Normal notification
                notify-send "Clipboard Image Saved" \
                    "Saved to: $LATEST_IMAGE\n\nFor Claude: Super+Alt+V" \
                    -i "$image_path" \
                    -t 4000

                echo "[$(date '+%H:%M:%S')] IMAGE: $claude_image" >> /tmp/clip-count.log
            fi

            echo "[$(date '+%H:%M:%S')] Saved image: $claude_image ($file_size bytes)" >> "$LOG_FILE"
        else
            # File is empty
            rm -f "$image_path" "$claude_image"
            echo "[$(date '+%H:%M:%S')] ERROR: Image file is 0 bytes" >> /tmp/clip-count.log
        fi
    else
        echo "[$(date '+%H:%M:%S')] ERROR: wl-paste failed for image" >> /tmp/clip-count.log
    fi
else
    # No image, check for text
    clipboard_content=$(wl-paste --no-newline 2>/dev/null)

    if [ -n "$clipboard_content" ]; then
        # Text content - only show notification if it's not too long
        content_length=${#clipboard_content}
        if [ $content_length -le 100 ]; then
            notify-send "Clipboard" "$clipboard_content" -t 2000
        else
            notify_send "Clipboard" "Text copied (${content_length} characters)" -t 2000
        fi
        echo "[$(date '+%H:%M:%S')] TEXT: ${clipboard_content:0:50}..." >> /tmp/clip-count.log
    else
        echo "[$(date '+%H:%M:%S')] EMPTY: No clipboard content" >> /tmp/clip-count.log
    fi
fi

echo "[$(date '+%H:%M:%S')] DONE" >> /tmp/clip-count.log

# Clean up old images (keep last 20)
cd "$CLAUDE_DIR" 2>/dev/null && \
    ls -t clipboard_*.png 2>/dev/null | tail -n +21 | xargs -r rm -f