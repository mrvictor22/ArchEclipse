#!/bin/bash
# Claude Clipboard Helper
# Makes it easy to access clipboard images in Claude Code

# Configuration
CLAUDE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$CLAUDE_DIR/latest.png"
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}         Claude Code Clipboard Helper${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

case "${1:-status}" in
    status)
        print_header
        echo ""
        echo -e "${GREEN}Clipboard Image Locations:${NC}"
        echo "1. Latest clipboard image: $LATEST_IMAGE"
        echo "2. Screenshots directory:  $SCREENSHOT_DIR"
        echo ""

        if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
            actual_file=$(readlink -f "$LATEST_IMAGE")
            file_size=$(du -h "$actual_file" | cut -f1)
            modified=$(stat -c %y "$actual_file" | cut -d. -f1)

            echo -e "${GREEN}Latest Clipboard Image Found:${NC}"
            echo "  File: $actual_file"
            echo "  Size: $file_size"
            echo "  Modified: $modified"
            echo ""
            echo -e "${YELLOW}To use in Claude Code, tell Claude:${NC}"
            echo -e "  ${GREEN}'Read $LATEST_IMAGE'${NC}"
            echo ""

            # Copy path to clipboard for convenience
            echo "$LATEST_IMAGE" | wl-copy
            echo -e "${GREEN}✓${NC} Path copied to clipboard!"
        else
            echo -e "${RED}✗${NC} No clipboard image found"
            echo ""
            echo "To capture an image:"
            echo "1. Copy any image to clipboard (from browser, file manager, etc.)"
            echo "2. Or take a screenshot with Super+Shift+S"
            echo ""
        fi

        # Show recent clipboard images
        echo ""
        echo -e "${GREEN}Recent Clipboard Images:${NC}"
        if ls "$CLAUDE_DIR"/clipboard_*.png 2>/dev/null | head -5 | while read -r file; do
            size=$(du -h "$file" | cut -f1)
            time=$(stat -c %y "$file" | cut -d' ' -f2 | cut -d. -f1)
            echo "  $time - $(basename "$file") ($size)"
        done | grep . ; then
            :
        else
            echo "  (none found)"
        fi
        ;;

    copy)
        # Copy an image to clipboard and save it for Claude
        if [ -z "$2" ]; then
            echo "Usage: $0 copy <image-file>"
            exit 1
        fi

        if [ ! -f "$2" ]; then
            echo -e "${RED}Error:${NC} File not found: $2"
            exit 1
        fi

        # Copy to clipboard
        wl-copy -t image/png < "$2"
        echo -e "${GREEN}✓${NC} Image copied to clipboard"
        echo ""
        echo "The clipboard monitor will automatically save it for Claude Code"
        echo "Wait a moment, then use: $0 status"
        ;;

    test)
        # Test the clipboard image functionality
        print_header
        echo ""
        echo -e "${YELLOW}Testing Clipboard Image System...${NC}"
        echo ""

        # Check if clipboard monitor is running
        if pgrep -f "wl-paste.*clipboard" >/dev/null; then
            echo -e "${GREEN}✓${NC} Clipboard monitor is running"
        else
            echo -e "${RED}✗${NC} Clipboard monitor is NOT running"
            echo "  Start it with: ~/.config/hypr/scripts/start-clipboard-monitor.sh"
        fi

        # Check directories
        if [ -d "$CLAUDE_DIR" ]; then
            echo -e "${GREEN}✓${NC} Claude directory exists: $CLAUDE_DIR"
        else
            echo -e "${RED}✗${NC} Claude directory missing: $CLAUDE_DIR"
            mkdir -p "$CLAUDE_DIR"
            echo "  Created directory"
        fi

        # Test image copying
        echo ""
        echo -e "${YELLOW}Testing image capture...${NC}"

        # Create a test image if latest screenshot exists
        test_source="$SCREENSHOT_DIR/latest.png"
        if [ -f "$test_source" ]; then
            echo "  Using test image: $test_source"
            wl-copy -t image/png < "$test_source"
            echo "  Image copied to clipboard"
            sleep 1

            # Check if it was saved
            if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
                echo -e "${GREEN}✓${NC} Image successfully captured to: $LATEST_IMAGE"
                echo ""
                echo -e "${GREEN}Test passed!${NC} System is working correctly."
            else
                echo -e "${RED}✗${NC} Image was not captured"
                echo "  Check /tmp/clip-count.log for errors"
            fi
        else
            echo "  No test image available"
            echo "  Take a screenshot first with Super+Shift+S"
        fi
        ;;

    clean)
        # Clean up old clipboard images
        echo "Cleaning up old clipboard images..."

        # Keep only the last 20 images
        cd "$CLAUDE_DIR" 2>/dev/null && \
            ls -t clipboard_*.png 2>/dev/null | tail -n +21 | xargs -r rm -v

        # Clean up 0-byte files in /tmp
        find /tmp -name "clipboard_image_*.png" -size 0 -delete -print

        echo "Cleanup complete"
        ;;

    help|*)
        print_header
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status  - Show current clipboard image status (default)"
        echo "  copy    - Copy an image file to clipboard"
        echo "  test    - Test the clipboard image system"
        echo "  clean   - Clean up old clipboard images"
        echo "  help    - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0              # Show status"
        echo "  $0 status       # Show status"
        echo "  $0 copy pic.png # Copy image to clipboard"
        echo "  $0 test         # Run system test"
        echo ""
        echo "For Claude Code:"
        echo "  After copying an image, tell Claude:"
        echo "  'Read $LATEST_IMAGE'"
        ;;
esac