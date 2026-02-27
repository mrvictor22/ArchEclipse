#!/bin/bash

# Lid Event Handler for Hyprland Multi-Monitor Setup
# Automatically handles lid open/close events for laptops

SCRIPT_DIR="$(dirname "$0")"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"

# Log file for debugging
LOG_FILE="/tmp/hyprland-lid-handler.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Ensure Hyprland environment is available (needed when running as systemd service)
ensure_hyprland_env() {
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        local hypr_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
        if [ -d "$hypr_dir" ]; then
            local sig=$(ls -1 "$hypr_dir" 2>/dev/null | head -1)
            if [ -n "$sig" ] && [ -S "$hypr_dir/$sig/.socket.sock" ]; then
                export HYPRLAND_INSTANCE_SIGNATURE="$sig"
                log "Auto-detected HYPRLAND_INSTANCE_SIGNATURE=$sig"
            fi
        fi
    fi

    if [ -z "$WAYLAND_DISPLAY" ]; then
        export WAYLAND_DISPLAY="wayland-1"
        log "Set default WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    fi
}

# Wait for Hyprland IPC to be ready (retries up to 30s)
wait_for_hyprland() {
    local retries=0
    local max_retries=15

    while [ $retries -lt $max_retries ]; do
        ensure_hyprland_env
        if hyprctl monitors -j &>/dev/null; then
            log "Hyprland IPC ready (attempt $((retries + 1)))"
            return 0
        fi
        retries=$((retries + 1))
        log "Waiting for Hyprland IPC (attempt $retries/$max_retries)..."
        sleep 2
    done

    log "ERROR: Hyprland IPC not available after $max_retries attempts"
    return 1
}

# Handle lid event
handle_lid() {
    log "Lid event detected, calling multi-monitor manager"
    
    if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
        "$MULTI_MONITOR_SCRIPT" lid
        log "Multi-monitor manager executed successfully"
    else
        log "ERROR: Multi-monitor manager script not found or not executable"
    fi
}

# Get current lid state
get_lid_state() {
    if [ -f "/proc/acpi/button/lid/LID/state" ]; then
        cat /proc/acpi/button/lid/LID/state | awk '{print $2}'
    elif [ -f "/proc/acpi/button/lid/LID0/state" ]; then
        cat /proc/acpi/button/lid/LID0/state | awk '{print $2}'
    else
        echo "unknown"
    fi
}

# Check if acpi_listen actually works (needs acpid running)
acpi_listen_works() {
    command -v acpi_listen &>/dev/null || return 1
    # Test with 1s timeout - if it exits immediately, acpid isn't running
    timeout 1 acpi_listen &>/dev/null
    # timeout returns 124 if it had to kill the process (meaning it was still running = working)
    [ $? -eq 124 ]
}

# Monitor lid events using acpi_listen (preferred) or polling (fallback)
monitor_lid_events() {
    log "Starting lid event monitoring"

    if acpi_listen_works; then
        log "Using acpi_listen for lid events (acpid running)"
        acpi_listen | while read -r event; do
            case "$event" in
                *"button/lid"*)
                    log "Lid event received: $event"
                    handle_lid
                    ;;
            esac
        done
    else
        if command -v acpi_listen &>/dev/null; then
            log "acpi_listen found but acpid not running, using polling fallback"
        else
            log "acpi_listen not available, using polling fallback"
        fi
        local last_state=$(get_lid_state)
        log "Initial lid state: $last_state"

        while true; do
            sleep 2
            local current_state=$(get_lid_state)

            if [ "$current_state" != "$last_state" ]; then
                log "Lid state changed: $last_state -> $current_state"
                last_state="$current_state"
                handle_lid
            fi
        done
    fi
}

# Check if running as systemd service or standalone
if [ "$1" = "monitor" ]; then
    log "Lid handler starting, waiting for Hyprland..."
    wait_for_hyprland || exit 1

    # Handle current state on startup (e.g. service restarted with lid already closed)
    log "Checking initial lid state on startup..."
    handle_lid
    monitor_lid_events
else
    ensure_hyprland_env
    handle_lid
fi
