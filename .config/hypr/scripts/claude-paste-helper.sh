#!/bin/bash
# Claude Paste Helper - Automatically handles image pasting for Claude Code
# This script provides multiple methods to work with clipboard images

# Configuration
CLAUDE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$CLAUDE_DIR/latest.png"
SCREENSHOT_LATEST="$HOME/Pictures/Screenshots/latest.png"
LOG_FILE="/tmp/claude-paste-helper.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to save current clipboard image
save_clipboard_image() {
    if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        image_path="$CLAUDE_DIR/clipboard_${timestamp}.png"
        mkdir -p "$CLAUDE_DIR"

        if wl-paste --type image/png > "$image_path" 2>/dev/null; then
            if [ -s "$image_path" ]; then
                ln -sf "$image_path" "$LATEST_IMAGE"
                log "Saved clipboard image: $image_path"
                echo "$LATEST_IMAGE"
                return 0
            else
                rm -f "$image_path"
            fi
        fi
    fi
    return 1
}

# Function to get the latest available image
get_latest_image() {
    # Priority order:
    # 1. Current clipboard (if it's an image)
    # 2. Claude clipboard latest
    # 3. Screenshot latest
    # 4. Most recent clipboard image
    # 5. Most recent screenshot

    # Try to save current clipboard first
    if image_path=$(save_clipboard_image); then
        echo "$image_path"
        return 0
    fi

    # Check Claude's latest
    if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
        if [ $(find "$LATEST_IMAGE" -mmin -10 2>/dev/null | wc -l) -gt 0 ]; then
            echo "$LATEST_IMAGE"
            return 0
        fi
    fi

    # Check screenshot latest
    if [ -L "$SCREENSHOT_LATEST" ] && [ -e "$SCREENSHOT_LATEST" ]; then
        if [ $(find "$SCREENSHOT_LATEST" -mmin -10 2>/dev/null | wc -l) -gt 0 ]; then
            echo "$SCREENSHOT_LATEST"
            return 0
        fi
    fi

    # Find most recent clipboard image
    latest=$(ls -t "$CLAUDE_DIR"/clipboard_*.png 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "$latest"
        return 0
    fi

    # Find most recent screenshot
    latest=$(ls -t "$HOME/Pictures/Screenshots/"*_hyprshot.png 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "$latest"
        return 0
    fi

    return 1
}

# Function to copy Claude command to clipboard
copy_claude_command() {
    local image_path="$1"
    local command="Read $image_path"

    echo -n "$command" | wl-copy
    log "Copied command to clipboard: $command"

    # Show notification with image preview
    notify-send "Claude Helper: Image Path Copied" \
        "$command\n\nNow press Ctrl+Shift+V in Claude Code terminal!" \
        -i "$image_path" \
        -t 5000

    echo "$command"
}

# Function to show current status
show_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}         Claude Code Paste Helper${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check for current clipboard image
    if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
        echo -e "${GREEN}✓${NC} Image detected in clipboard"
    else
        echo -e "${YELLOW}⚠${NC} No image in clipboard"
    fi

    # Check for latest images
    if image_path=$(get_latest_image); then
        file_size=$(du -h "$image_path" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓${NC} Latest image found: $image_path ($file_size)"
        echo ""
        echo -e "${YELLOW}To use in Claude Code:${NC}"
        echo -e "  1. Run: ${GREEN}$0 copy${NC}"
        echo -e "  2. Press ${GREEN}Ctrl+V${NC} in Claude Code chat"
        echo ""
        echo -e "${BLUE}Or use the keyboard shortcut:${NC}"
        echo -e "  ${GREEN}Super+Alt+V${NC} - Auto-copy image path"
    else
        echo -e "${RED}✗${NC} No recent images found"
        echo ""
        echo "Take a screenshot or copy an image first!"
    fi
}

# Main execution
case "${1:-status}" in
    copy)
        # Copy the Claude command for the latest image
        if image_path=$(get_latest_image); then
            copy_claude_command "$image_path"
            echo -e "${GREEN}✓${NC} Command copied! Press Ctrl+V in Claude Code"
        else
            echo -e "${RED}✗${NC} No image available"
            notify-send "Claude Helper" "No image found to copy" -u warning
            exit 1
        fi
        ;;

    save)
        # Save current clipboard image
        if image_path=$(save_clipboard_image); then
            echo -e "${GREEN}✓${NC} Image saved: $image_path"
            copy_claude_command "$image_path"
        else
            echo -e "${RED}✗${NC} No image in clipboard"
            exit 1
        fi
        ;;

    auto)
        # Automatic mode - save if image, then copy command
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            # Image in clipboard - save and copy command
            if image_path=$(save_clipboard_image); then
                copy_claude_command "$image_path"
            fi
        else
            # No image - try to get latest and copy command
            if image_path=$(get_latest_image); then
                copy_claude_command "$image_path"
            else
                notify-send "Claude Helper" "No image available" -u warning
            fi
        fi
        ;;

    status)
        show_status
        ;;

    test)
        # Test mode
        echo "Testing Claude Paste Helper..."
        echo ""

        # Check clipboard
        echo -n "Clipboard has image: "
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            echo -e "${GREEN}Yes${NC}"
        else
            echo -e "${RED}No${NC}"
        fi

        # Check directories
        echo -n "Claude directory exists: "
        if [ -d "$CLAUDE_DIR" ]; then
            echo -e "${GREEN}Yes${NC}"
            image_count=$(ls "$CLAUDE_DIR"/clipboard_*.png 2>/dev/null | wc -l)
            echo "  Images saved: $image_count"
        else
            echo -e "${RED}No${NC}"
        fi

        # Try to get latest image
        echo ""
        if image_path=$(get_latest_image); then
            echo -e "${GREEN}✓${NC} Latest image: $image_path"
            echo ""
            echo "Test: Copying command to clipboard..."
            copy_claude_command "$image_path"
            echo -e "${GREEN}✓${NC} Test successful!"
        else
            echo -e "${RED}✗${NC} No images found"
        fi
        ;;

    clean)
        # Clean up old images
        echo "Cleaning up old clipboard images..."
        cd "$CLAUDE_DIR" 2>/dev/null && \
            ls -t clipboard_*.png 2>/dev/null | tail -n +21 | xargs -r rm -v
        echo "Cleanup complete"
        ;;

    help|*)
        echo "Usage: $0 {copy|save|auto|status|test|clean|help}"
        echo ""
        echo "Commands:"
        echo "  copy    - Copy 'Read <path>' command for latest image"
        echo "  save    - Save current clipboard image and copy command"
        echo "  auto    - Smart mode: save if new image, copy command"
        echo "  status  - Show current status (default)"
        echo "  test    - Test the system"
        echo "  clean   - Clean up old images"
        echo "  help    - Show this help"
        echo ""
        echo "Workflow:"
        echo "  1. Copy/screenshot an image"
        echo "  2. Run: $0 auto"
        echo "  3. Press Ctrl+V in Claude Code"
        ;;
esac