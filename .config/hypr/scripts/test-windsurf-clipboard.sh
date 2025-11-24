#!/bin/bash
# Test Windsurf Clipboard Integration
# This script helps diagnose clipboard issues with Windsurf on Wayland

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    Windsurf Clipboard Integration Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if Windsurf is running
echo -e "${YELLOW}1. Checking if Windsurf is running...${NC}"
if pgrep -f "windsurf" > /dev/null; then
    echo -e "${GREEN}   ✓${NC} Windsurf is running"

    # Check which flags it's using
    echo ""
    echo -e "${YELLOW}2. Checking Windsurf launch flags...${NC}"
    windsurf_cmd=$(ps aux | grep -i windsurf | grep -v grep | head -1)

    if echo "$windsurf_cmd" | grep -q "ozone-platform=wayland"; then
        echo -e "${GREEN}   ✓${NC} Using Wayland backend"
    else
        echo -e "${RED}   ✗${NC} NOT using Wayland backend"
        echo -e "     ${YELLOW}Close Windsurf and relaunch from AGS launcher${NC}"
    fi

    if echo "$windsurf_cmd" | grep -q "enable-features.*Wayland"; then
        echo -e "${GREEN}   ✓${NC} Wayland features enabled"
    else
        echo -e "${RED}   ✗${NC} Wayland features NOT enabled"
    fi
else
    echo -e "${YELLOW}   →${NC} Windsurf is not running"
    echo -e "     Launch it from AGS (Super+Space) and run this test again"
fi

echo ""
echo -e "${YELLOW}3. Checking Wayland environment...${NC}"
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo -e "${GREEN}   ✓${NC} WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
else
    echo -e "${RED}   ✗${NC} WAYLAND_DISPLAY not set"
fi

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo -e "${GREEN}   ✓${NC} XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
else
    echo -e "${YELLOW}   →${NC} XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
fi

echo ""
echo -e "${YELLOW}4. Testing clipboard with image...${NC}"
if [ -f ~/Pictures/Screenshots/latest.png ]; then
    # Copy test image to clipboard
    wl-copy -t image/png < ~/Pictures/Screenshots/latest.png
    echo -e "${GREEN}   ✓${NC} Test image copied to clipboard"

    sleep 1

    # Check if clipboard contains image
    if wl-paste -l | grep -q "image/png"; then
        echo -e "${GREEN}   ✓${NC} Clipboard contains image/png"

        # Show current clipboard types
        echo ""
        echo -e "   ${BLUE}Available clipboard types:${NC}"
        wl-paste -l | while read type; do
            echo -e "     - $type"
        done
    else
        echo -e "${RED}   ✗${NC} Clipboard does not contain image"
    fi
else
    echo -e "${YELLOW}   →${NC} No test image found"
    echo -e "     Take a screenshot with Super+Shift+S first"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Close Windsurf completely (if running)"
echo "2. Launch Windsurf from AGS launcher (Super+Space)"
echo "3. Copy an image (take screenshot or copy from browser)"
echo "4. Try to paste in Windsurf with Ctrl+V"
echo ""
echo "If pasting still doesn't work, try:"
echo "- Check Windsurf settings: File > Preferences > Settings"
echo "  Search for 'clipboard' and ensure clipboard is enabled"
echo "- Use the workaround: Tell Claude Code to read the image file directly"
echo "  Example: 'Read ~/Pictures/Screenshots/latest.png'"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
