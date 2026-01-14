#!/bin/bash

# =============================================================================
# Random All Wallpapers - Apply random wallpapers to all workspaces at once
# =============================================================================
# Usage: random-all-wallpapers.sh <monitor> <category>
# Categories: defaults, custom, discretion, all
# =============================================================================

set -uo pipefail

MONITOR="${1:-}"
CATEGORY="${2:-all}"

HYPR_DIR="$HOME/.config/hypr"
WALLPAPER_DIR="$HOME/.config/wallpapers"
CONFIG_DIR="$HYPR_DIR/hyprpaper/config"

NUM_WORKSPACES=10

if [[ -z "$MONITOR" ]]; then
    echo "Usage: $0 <monitor> [category]"
    echo "Categories: defaults, custom, discretion, all"
    exit 1
fi

# Get wallpapers based on category
get_wallpapers() {
    local category="$1"
    local dirs=()

    case "$category" in
        defaults)
            dirs=("$WALLPAPER_DIR/defaults")
            ;;
        custom)
            dirs=("$WALLPAPER_DIR/custom")
            ;;
        discretion)
            dirs=("$WALLPAPER_DIR/discretion")
            ;;
        all|*)
            dirs=("$WALLPAPER_DIR/defaults" "$WALLPAPER_DIR/custom")
            ;;
    esac

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null
        fi
    done
}

# Get shuffled wallpapers
mapfile -t wallpapers < <(get_wallpapers "$CATEGORY" | shuf)

if [[ ${#wallpapers[@]} -lt $NUM_WORKSPACES ]]; then
    echo "Error: Not enough wallpapers (found ${#wallpapers[@]}, need $NUM_WORKSPACES)"
    exit 1
fi

# Ensure config directory exists
mkdir -p "$CONFIG_DIR/$MONITOR"

config_file="$CONFIG_DIR/$MONITOR/defaults.conf"

# Write new config with random wallpapers
> "$config_file"
for ws in $(seq 1 $NUM_WORKSPACES); do
    idx=$((ws - 1))
    echo "w-${ws}=${wallpapers[$idx]}" >> "$config_file"
done

# Get current workspace for this monitor
current_ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$MONITOR\") | .activeWorkspace.id")

if [[ -n "$current_ws" ]]; then
    # Apply wallpaper for current workspace only
    wallpaper="${wallpapers[$((current_ws - 1))]}"
    hyprctl hyprpaper wallpaper "$MONITOR,$wallpaper"
fi

echo "Applied random wallpapers to all workspaces on $MONITOR"
