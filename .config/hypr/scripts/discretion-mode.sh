#!/bin/bash

# =============================================================================
# Discretion Mode - Wallpaper manager for screen sharing
# =============================================================================
# Switches between normal wallpapers (waifus) and SFW wallpapers from Wallhaven
# Works with the per-workspace wallpaper configuration system
# Usage: discretion-mode.sh [on|off|toggle|status|fetch|apply]
# =============================================================================

set -uo pipefail

# Directories
HYPR_DIR="$HOME/.config/hypr"
WALLPAPER_DIR="$HOME/.config/wallpapers"
DISCRETION_DIR="$WALLPAPER_DIR/discretion"
CACHE_DIR="$HOME/.cache/hypr"
STATE_FILE="$CACHE_DIR/discretion-mode"
BACKUP_DIR="$CACHE_DIR/discretion-backup"
CONFIG_DIR="$HYPR_DIR/hyprpaper/config"
SCRIPTS_DIR="$HYPR_DIR/scripts"

# Wallhaven API
WALLHAVEN_API="https://wallhaven.cc/api/v1/search"

# Search queries for SFW wallpapers (user preferences)
QUERIES=(
    "anime"
    "video games"
    "japan culture"
    "japanese aesthetic"
    "jdm cars"
    "japanese cars"
    "formula 1"
    "f1 racing"
    "pokemon"
    "guitar"
    "electric guitar"
    "japanese landscape"
    "tokyo cityscape"
    "mount fuji"
    "initial d"
    "gt3 racing"
)

# Number of workspaces
NUM_WORKSPACES=10

# Minimum wallpapers to keep cached
MIN_WALLPAPERS=20

# =============================================================================
# Helper functions
# =============================================================================

log() {
    echo "[discretion-mode] $1"
}

error() {
    echo "[discretion-mode] ERROR: $1" >&2
}

ensure_dirs() {
    mkdir -p "$DISCRETION_DIR"
    mkdir -p "$CACHE_DIR"
    mkdir -p "$BACKUP_DIR"
}

get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "off"
    fi
}

set_state() {
    echo "$1" > "$STATE_FILE"
}

get_monitors() {
    hyprctl monitors -j | jq -r '.[].name'
}

get_random_discretion_wallpaper() {
    find "$DISCRETION_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1
}

count_discretion_wallpapers() {
    find "$DISCRETION_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | wc -l
}

# =============================================================================
# Wallhaven API functions
# =============================================================================

fetch_wallpaper_url() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')

    # API parameters:
    # - purity=100 = SFW only
    # - categories=111 = general + anime + people
    # - sorting=random = randomize results
    # - atleast=1920x1080 = minimum resolution
    local url="${WALLHAVEN_API}?q=${encoded_query}&purity=100&categories=111&sorting=random&atleast=1920x1080"

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$url" 2>/dev/null)

    if [[ -z "$response" ]]; then
        return 1
    fi

    # Extract a random wallpaper path from results
    local wallpaper_url
    wallpaper_url=$(echo "$response" | jq -r '.data[].path' 2>/dev/null | shuf -n 1)

    if [[ -z "$wallpaper_url" || "$wallpaper_url" == "null" ]]; then
        return 1
    fi

    echo "$wallpaper_url"
}

download_wallpaper() {
    local url="$1"
    local filename
    filename=$(basename "$url")
    local destination="$DISCRETION_DIR/$filename"

    if [[ -f "$destination" ]]; then
        log "Wallpaper already exists: $filename"
        return 0
    fi

    log "Downloading: $filename"
    if curl -s --connect-timeout 10 --max-time 60 -o "$destination" "$url"; then
        log "Downloaded: $filename"
        return 0
    else
        error "Failed to download: $url"
        rm -f "$destination"
        return 1
    fi
}

# =============================================================================
# Config management functions
# =============================================================================

backup_configs() {
    log "Backing up wallpaper configurations..."

    local monitors
    monitors=$(get_monitors)

    for monitor in $monitors; do
        local config_file="$CONFIG_DIR/$monitor/defaults.conf"
        local backup_file="$BACKUP_DIR/$monitor-defaults.conf"

        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$backup_file"
            log "Backed up: $monitor"
        fi
    done
}

restore_configs() {
    log "Restoring wallpaper configurations..."

    local monitors
    monitors=$(get_monitors)

    for monitor in $monitors; do
        local config_file="$CONFIG_DIR/$monitor/defaults.conf"
        local backup_file="$BACKUP_DIR/$monitor-defaults.conf"

        if [[ -f "$backup_file" ]]; then
            cp "$backup_file" "$config_file"
            log "Restored: $monitor"
        fi
    done
}

apply_discretion_wallpapers() {
    log "Applying discretion wallpapers to all workspaces..."

    local monitors
    monitors=$(get_monitors)

    for monitor in $monitors; do
        local config_file="$CONFIG_DIR/$monitor/defaults.conf"

        # Ensure config directory exists
        mkdir -p "$CONFIG_DIR/$monitor"

        # Get all wallpapers shuffled (unique per workspace)
        local -a shuffled_wallpapers
        mapfile -t shuffled_wallpapers < <(find "$DISCRETION_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | shuf)

        # Generate new config with unique wallpapers per workspace
        > "$config_file"  # Clear file

        for ws in $(seq 1 $NUM_WORKSPACES); do
            local idx=$((ws - 1))
            local wallpaper="${shuffled_wallpapers[$idx]:-}"

            if [[ -n "$wallpaper" ]]; then
                echo "w-${ws}=${wallpaper}" >> "$config_file"
            fi
        done

        log "Applied discretion config to: $monitor (${#shuffled_wallpapers[@]} wallpapers available)"
    done
}

apply_wallpapers_to_current() {
    log "Applying wallpapers to current workspaces..."

    local monitors
    monitors=$(get_monitors)

    for monitor in $monitors; do
        local config_file="$CONFIG_DIR/$monitor/defaults.conf"

        # Get current workspace for this monitor
        local current_ws
        current_ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$monitor\") | .activeWorkspace.id")

        if [[ -n "$current_ws" && -f "$config_file" ]]; then
            # Get wallpaper for current workspace
            local wallpaper
            wallpaper=$(grep "^w-${current_ws}=" "$config_file" | cut -d'=' -f2)

            # Expand $HOME if present
            wallpaper=$(eval echo "$wallpaper")

            if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
                log "Setting wallpaper on $monitor (workspace $current_ws): $(basename "$wallpaper")"
                hyprctl hyprpaper wallpaper "$monitor,$wallpaper"
            fi
        fi
    done
}

# =============================================================================
# Main functions
# =============================================================================

cmd_fetch() {
    local count="${1:-5}"
    ensure_dirs

    log "Fetching $count wallpapers from Wallhaven..."

    local downloaded=0
    local attempts=0
    local max_attempts=$((count * 3))

    while [[ $downloaded -lt $count && $attempts -lt $max_attempts ]]; do
        # Pick a random query
        local query="${QUERIES[$RANDOM % ${#QUERIES[@]}]}"
        log "Searching: $query"

        local url
        if url=$(fetch_wallpaper_url "$query"); then
            if download_wallpaper "$url"; then
                ((downloaded++))
            fi
        else
            log "No results for: $query"
        fi

        ((attempts++))

        # Small delay to respect rate limits
        sleep 0.5
    done

    log "Downloaded $downloaded wallpapers"
    log "Total discretion wallpapers: $(count_discretion_wallpapers)"
}

cmd_on() {
    ensure_dirs

    # Check if already on - don't overwrite backup
    local current_state
    current_state=$(get_state)
    if [[ "$current_state" == "on" ]]; then
        log "Discretion mode is already ON"
        return 0
    fi

    local count
    count=$(count_discretion_wallpapers)

    if [[ $count -lt $MIN_WALLPAPERS ]]; then
        log "Not enough discretion wallpapers ($count < $MIN_WALLPAPERS)"
        log "Fetching more wallpapers first..."
        cmd_fetch $((MIN_WALLPAPERS - count + 5))
    fi

    # Backup current configs before switching (only when turning ON from OFF)
    backup_configs

    # Set discretion wallpapers for all workspaces
    apply_discretion_wallpapers

    # Apply to current monitors
    apply_wallpapers_to_current

    set_state "on"

    notify-send -u normal -t 3000 -i preferences-desktop-wallpaper \
        "Modo Discreción" "Activado - Wallpapers SFW"

    log "Discretion mode: ON"
}

cmd_off() {
    ensure_dirs

    # Restore original configs
    restore_configs

    # Apply to current monitors
    apply_wallpapers_to_current

    set_state "off"

    notify-send -u normal -t 3000 -i preferences-desktop-wallpaper \
        "Modo Discreción" "Desactivado - Wallpapers normales"

    log "Discretion mode: OFF"
}

cmd_toggle() {
    local current
    current=$(get_state)

    if [[ "$current" == "on" ]]; then
        cmd_off
    else
        cmd_on
    fi
}

cmd_status() {
    local state
    state=$(get_state)
    local count
    count=$(count_discretion_wallpapers)

    echo "Discretion Mode: $state"
    echo "Cached wallpapers: $count"
    echo "Wallpaper directory: $DISCRETION_DIR"
    echo "Backup directory: $BACKUP_DIR"

    # Return state for scripting (0 = on, 1 = off)
    if [[ "$state" == "on" ]]; then
        return 0
    else
        return 1
    fi
}

cmd_apply() {
    apply_wallpapers_to_current
}

cmd_help() {
    cat << EOF
Discretion Mode - Wallpaper manager for screen sharing

Usage: $(basename "$0") <command> [options]

Commands:
    on          Enable discretion mode (SFW wallpapers for all workspaces)
    off         Disable discretion mode (restore original wallpapers)
    toggle      Toggle between modes
    status      Show current mode and stats
    fetch [N]   Download N wallpapers from Wallhaven (default: 5)
    apply       Re-apply wallpapers for current workspaces
    help        Show this help message

Examples:
    $(basename "$0") toggle          # Quick toggle for keybind
    $(basename "$0") fetch 10        # Pre-download 10 wallpapers
    $(basename "$0") status          # Check current mode

Notes:
    - Discretion mode replaces ALL workspace wallpapers on ALL monitors
    - Original wallpaper configs are backed up and restored when turned off
    - Wallpapers are fetched from Wallhaven with SFW filter
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local cmd="${1:-help}"

    case "$cmd" in
        on)
            cmd_on
            ;;
        off)
            cmd_off
            ;;
        toggle)
            cmd_toggle
            ;;
        status)
            cmd_status
            ;;
        fetch)
            cmd_fetch "${2:-5}"
            ;;
        apply)
            cmd_apply
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
