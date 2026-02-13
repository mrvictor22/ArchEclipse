#!/bin/bash
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Pictures/Screenshots"

# create screenshot directory if it doesn't exist
mkdir -p "$screenshot_dir"

if [[ "$1" == "--now" ]]; then
    img="$screenshot_dir/screenshot_${timestamp}.png"
    hyprshot -m output -o "$screenshot_dir" -f "screenshot_${timestamp}.png"

elif [[ "$1" == "--area" ]]; then
    img="$screenshot_dir/screenshot_area_${timestamp}.png"
    hyprshot -m region -o "$screenshot_dir" -f "screenshot_area_${timestamp}.png"

else
    echo -e "Available Options : --now --area"
    exit 1
fi

# Create latest.png symlink for Claude Code compatibility
if [ -f "$img" ]; then
    ln -sf "$img" "$screenshot_dir/latest.png"

    # Send image to clipboard
    wl-copy --type image/png < "$img"
fi
