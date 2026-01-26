#!/usr/bin/env bash
# Clipboard Monitor - Hybrid version
# Fork singleton system + Upstream features (image preview/edit, video play/save)
set -euo pipefail

# =========================
# Logging (for debugging with singleton)
# =========================
LOG_FILE="/tmp/clip-count.log"
log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

log "EXEC - clipboard event received"

# =========================
# Config
# =========================
TMP_DIR="/tmp"
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
VIDEO_DIR="$HOME/Videos/ScreenRecords"

# Ensure directories exist
mkdir -p "$SCREENSHOT_DIR" "$VIDEO_DIR"

# =========================
# 1. Try IMAGE from clipboard
# =========================
timestamp=$(date +%Y%m%d_%H%M%S)
image_path="$TMP_DIR/clipboard_image_${timestamp}.webp"

if wl-paste --type image/png >"$image_path" 2>/dev/null && [ -s "$image_path" ]; then
    log "IMAGE detected, showing notification"

    action=$(notify-send "Clipboard Image" "Image copied to clipboard" \
        -a "Screenshot" \
        -i "$image_path" \
        --action=preview:Preview \
        --action=edit:Edit \
        --action=save:Save 2>/dev/null || echo "")

    log "ACTION: $action"

    case "$action" in
        preview)
            swayimg --class preview-image "$image_path" &
            ;;
        edit)
            gimp "$image_path" &
            ;;
        save)
            save_path=$(zenity --file-selection \
                --save \
                --confirm-overwrite \
                --filename="$SCREENSHOT_DIR/clipboard_${timestamp}.png" \
                --title="Save Image" 2>/dev/null || echo "")

            if [ -n "$save_path" ]; then
                cp "$image_path" "$save_path"
                notify-send "Image Saved" "$(basename "$save_path")" -i "$save_path"
                log "SAVED to $save_path"
            fi
            ;;
    esac

    log "DONE (image)"
    exit 0
fi

# Clean up empty image file
rm -f "$image_path" 2>/dev/null || true

# =========================
# 2. Try VIDEO URI from clipboard (screen recordings)
# =========================
if clipboard_uri=$(wl-paste --no-newline --type text/uri-list 2>/dev/null) && [[ -n "$clipboard_uri" ]]; then
    # Extract file path from URI (file:///path/to/file -> /path/to/file)
    file_path="${clipboard_uri#file://}"

    # Check if it's a video file
    extension="${file_path##*.}"
    if [[ "$extension" =~ ^(mp4|webm|mkv|avi|mov)$ ]] && [ -f "$file_path" ]; then
        log "VIDEO URI detected: $file_path"

        action=$(notify-send -i "video-x-generic" "Video Copied" "$file_path" \
            -a "ScreenRecord" \
            --action=play:Play \
            --action=save:Save 2>/dev/null || echo "")

        log "ACTION: $action"

        case "$action" in
            play)
                vlc "$file_path" &
                ;;
            save)
                save_path=$(zenity --file-selection \
                    --save \
                    --confirm-overwrite \
                    --filename="$VIDEO_DIR/recording_${timestamp}.$extension" \
                    --title="Save Video" 2>/dev/null || echo "")

                if [ -n "$save_path" ]; then
                    cp "$file_path" "$save_path"
                    notify-send "Video Saved" "$(basename "$save_path")" -i "video-x-generic"
                    log "SAVED to $save_path"
                fi
                ;;
        esac

        log "DONE (video)"
        exit 0
    fi
fi

# =========================
# 3. Fallback: TEXT clipboard
# =========================
if clipboard_text=$(wl-paste --no-newline --type text 2>/dev/null) && [[ -n "$clipboard_text" ]]; then
    # Truncate long text for notification (max 200 chars)
    display_text="${clipboard_text:0:200}"
    [ ${#clipboard_text} -gt 200 ] && display_text="${display_text}..."

    notify-send -i "edit-copy" -a "Clipboard" "Text Copied" "$display_text"
    log "TEXT: ${clipboard_text:0:50}..."
    log "DONE (text)"
    exit 0
fi

log "DONE (no content detected)"
