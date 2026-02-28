#!/bin/bash

# Multi-Monitor Manager for Hyprland
# Detects device type, manages monitor configurations, and handles lid events
# Author: ArchEclipse Rice Configuration

# Configuration paths
HYPR_CONFIG_DIR="$HOME/.config/hypr"
MONITORS_CONFIG="$HYPR_CONFIG_DIR/configs/monitors.conf"
CUSTOM_MONITORS_CONFIG="$HYPR_CONFIG_DIR/configs/custom/monitors.conf"
LOGIND_CONFIG="/etc/systemd/logind.conf"
LOCKFILE="/tmp/hyprland-monitor-manager.lock"

# --- Lid behavior settings ---
# Internal monitor name fallback (used when monitor is disabled and not detected dynamically)
INTERNAL_MONITOR_FALLBACK="eDP-1"

# Set to true to require AC power for lid-close workspace migration.
# Set to false (default) to always migrate workspaces to external monitor on lid close.
REQUIRE_AC_FOR_LID_ACTION=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
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
    fi
}

# Auto-detect env before any hyprctl calls
ensure_hyprland_env

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect device type (laptop or desktop)
detect_device_type() {
    local device_type=""
    
    # Check for laptop indicators
    if [ -d "/proc/acpi/button/lid" ] || [ -f "/sys/class/power_supply/BAT0/present" ] || [ -f "/sys/class/power_supply/BAT1/present" ]; then
        device_type="laptop"
    elif lscpu | grep -q "Mobile"; then
        device_type="laptop"
    else
        device_type="desktop"
    fi
    
    # Check for internal display (eDP)
    if hyprctl monitors -j | jq -r '.[].name' | grep -q "eDP"; then
        device_type="laptop"
    fi
    
    echo "$device_type"
}

# Get monitor information
get_monitors_info() {
    hyprctl monitors -j
}

# Get internal monitor name (usually eDP-1 for laptops)
# Falls back to INTERNAL_MONITOR_FALLBACK when monitor is disabled and not listed
get_internal_monitor() {
    local detected
    detected=$(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -1)
    if [ -n "$detected" ]; then
        echo "$detected"
    else
        echo "$INTERNAL_MONITOR_FALLBACK"
    fi
}

# Get external monitors
get_external_monitors() {
    hyprctl monitors -j | jq -r '.[] | select(.name | startswith("eDP") | not) | .name'
}

# Check if AC adapter is connected
is_ac_connected() {
    local ac_status=""
    for ac in /sys/class/power_supply/A{C,DP}*; do
        if [ -f "$ac/online" ]; then
            ac_status=$(cat "$ac/online")
            if [ "$ac_status" = "1" ]; then
                return 0
            fi
        fi
    done
    return 1
}

# Check if lid is closed
is_lid_closed() {
    if [ -f "/proc/acpi/button/lid/LID0/state" ]; then
        grep -q "closed" /proc/acpi/button/lid/LID0/state
    elif [ -f "/proc/acpi/button/lid/LID/state" ]; then
        grep -q "closed" /proc/acpi/button/lid/LID/state
    else
        return 1
    fi
}

# Configure lid behavior for laptops
configure_lid_behavior() {
    local device_type=$(detect_device_type)
    
    if [ "$device_type" = "laptop" ]; then
        log "Configuring laptop lid behavior..."
        
        # Create systemd logind configuration for lid handling
        if [ ! -f "$LOGIND_CONFIG.backup" ]; then
            sudo cp "$LOGIND_CONFIG" "$LOGIND_CONFIG.backup" 2>/dev/null || true
        fi
        
        # Configure logind to ignore lid switch when external monitor is connected
        cat << EOF | sudo tee /etc/systemd/logind.conf.d/99-hyprland-lid.conf > /dev/null
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
        
        # Restart logind service
        sudo systemctl restart systemd-logind
        
        log "Lid behavior configured successfully"
    fi
}

# Restart AGS to apply multi-monitor configuration (detached from service cgroup)
restart_ags() {
    log "Restarting AGS for multi-monitor support..."

    # Kill existing AGS instances
    pkill -x "ags" 2>/dev/null || true
    sleep 1
    killall gjs 2>/dev/null || true
    sleep 0.5

    # Clean up previous scope if it exists
    systemctl --user stop ags-bar.scope 2>/dev/null || true
    systemctl --user reset-failed ags-bar.scope 2>/dev/null || true

    # Start AGS in its own scope (detached from any service cgroup)
    if command -v systemd-run &>/dev/null; then
        systemd-run --user --scope --unit=ags-bar \
            env LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so GDK_BACKEND=wayland \
            ags run --gtk 3 --log-file /tmp/ags.log &
    else
        setsid env LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so GDK_BACKEND=wayland \
            ags run --gtk 3 --log-file /tmp/ags.log &
    fi
    disown 2>/dev/null

    log "AGS restarted successfully (detached)"
}

# Generate monitor configuration based on detected setup
generate_monitor_config() {
    local device_type=$(detect_device_type)
    local internal_monitor=$(get_internal_monitor)
    local external_monitors=($(get_external_monitors))
    local config_content=""
    
    log "Generating monitor configuration for $device_type..."
    
    # Base configuration header
    config_content+="#Monitor Configuration - Auto-generated by multi-monitor-manager\n"
    config_content+="# Device Type: $device_type\n"
    config_content+="# Generated: $(date)\n\n"
    
    if [ "$device_type" = "laptop" ]; then
        local lid_closed=false
        is_lid_closed && lid_closed=true

        if [ -n "$internal_monitor" ]; then
            if [ "$lid_closed" = true ] && [ ${#external_monitors[@]} -gt 0 ]; then
                config_content+="# Internal laptop display (lid closed - disabled)\n"
                config_content+="monitor = $internal_monitor, disable\n\n"
            else
                config_content+="# Internal laptop display\n"
                config_content+="monitor = $internal_monitor, preferred, 0x0, 1\n\n"
            fi
        fi

        # Configure external monitors
        # When lid is closed, external starts at 0x0; otherwise offset by internal width
        local x_offset=0
        if [ "$lid_closed" = false ] && [ -n "$internal_monitor" ]; then
            local internal_width=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$internal_monitor\") | .width")
            if [ -n "$internal_width" ] && [ "$internal_width" != "null" ]; then
                x_offset=$internal_width
            fi
        fi
        
        for monitor in "${external_monitors[@]}"; do
            if [ -n "$monitor" ]; then
                config_content+="# External monitor: $monitor\n"
                config_content+="monitor = $monitor, preferred, ${x_offset}x0, 1\n\n"
                
                # Update offset for next monitor
                local monitor_width=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .width")
                x_offset=$((x_offset + monitor_width))
            fi
        done
        
        # Add lid-closed configuration
        if [ ${#external_monitors[@]} -gt 0 ]; then
            config_content+="# Lid closed configuration - disable internal when external is connected\n"
            config_content+="# This will be managed dynamically by the lid event handler\n\n"
        fi
        
    else
        # Desktop configuration
        config_content+="# Desktop multi-monitor setup\n"
        config_content+="monitor = , preferred, auto, 1\n\n"
        
        # Configure each monitor explicitly if multiple are detected
        local x_offset=0
        local monitors_info=$(get_monitors_info)
        local monitor_count=$(echo "$monitors_info" | jq length)
        
        if [ "$monitor_count" -gt 1 ]; then
            for monitor in $(echo "$monitors_info" | jq -r '.[].name'); do
                config_content+="monitor = $monitor, preferred, ${x_offset}x0, 1\n"
                local monitor_width=$(echo "$monitors_info" | jq -r ".[] | select(.name == \"$monitor\") | .width")
                x_offset=$((x_offset + monitor_width))
            done
        fi
    fi
    
    # Write configuration
    mkdir -p "$(dirname "$MONITORS_CONFIG")"
    echo -e "$config_content" > "$MONITORS_CONFIG"
    
    log "Monitor configuration generated and saved to $MONITORS_CONFIG"
}

# Handle lid events for laptops
handle_lid_event() {
    local device_type=$(detect_device_type)
    
    if [ "$device_type" != "laptop" ]; then
        return 0
    fi
    
    local internal_monitor=$(get_internal_monitor)
    local external_monitors=($(get_external_monitors))

    log "Lid event: internal=$internal_monitor, externals=${#external_monitors[@]}, lid_closed=$(is_lid_closed && echo yes || echo no), ac=$(is_ac_connected && echo yes || echo no)"

    # Build lid-close condition: external monitor required, AC optional
    local lid_close_condition=false
    if is_lid_closed && [ ${#external_monitors[@]} -gt 0 ]; then
        if [ "$REQUIRE_AC_FOR_LID_ACTION" = true ]; then
            is_ac_connected && lid_close_condition=true
        else
            lid_close_condition=true
        fi
    fi

    if [ "$lid_close_condition" = true ]; then
        log "Lid closed with external monitor detected (AC required: $REQUIRE_AC_FOR_LID_ACTION)"
        log "Generating persistent config with eDP-1 disabled"

        # Generate config with eDP-1 disabled (generate_monitor_config checks is_lid_closed)
        generate_monitor_config
        hyprctl reload

        # Wait for config to apply
        sleep 1

        # Move all workspaces to the first external monitor
        local primary_external="${external_monitors[0]}"
        if [ -n "$primary_external" ]; then
            for workspace in $(hyprctl workspaces -j | jq -r '.[].id'); do
                hyprctl dispatch moveworkspacetomonitor "$workspace" "$primary_external"
            done

            # Focus the external monitor
            hyprctl dispatch focusmonitor "$primary_external"
        fi

        restart_ags

    elif is_lid_closed && [ ${#external_monitors[@]} -eq 0 ]; then
        log "Lid closed with no external monitor — suspending system"
        systemctl suspend

    elif ! is_lid_closed; then
        log "Lid opened, regenerating monitor config (eDP-1 + externals with correct offsets)"

        # Regenerate full config: eDP-1 at 0x0, externals offset correctly
        generate_monitor_config
        hyprctl reload

        # Wait for config to apply, then redistribute
        sleep 1
        redistribute_workspaces
        restart_ags
    fi
}

# Get workspace ID where btop is running
get_btop_workspace() {
    # btop runs in foot terminal - foot doesn't show child process in title,
    # so we detect by PID: find btop process, get its parent (foot), match in hyprctl clients
    local btop_pid=$(pgrep -x btop | head -1)
    if [ -z "$btop_pid" ]; then
        echo ""
        return
    fi
    local parent_pid=$(ps -o ppid= -p "$btop_pid" | tr -d ' ')
    local workspace=$(hyprctl clients -j | jq -r --arg pid "$parent_pid" \
        '.[] | select(.pid == ($pid | tonumber)) | .workspace.id' | head -1)
    echo "$workspace"
}

# Redistribute workspaces across available monitors
# When external monitor is connected:
#   - All workspaces go to external monitor
#   - EXCEPT the workspace containing btop, which stays on internal (eDP-1)
redistribute_workspaces() {
    local internal_monitor=$(get_internal_monitor)
    local external_monitors=($(get_external_monitors))
    local monitor_count=$((1 + ${#external_monitors[@]}))

    # If only one monitor, nothing to redistribute
    if [ "$monitor_count" -le 1 ] || [ ${#external_monitors[@]} -eq 0 ]; then
        log "Only one monitor detected, skipping redistribution"
        return 0
    fi

    local primary_external="${external_monitors[0]}"
    local btop_workspace=$(get_btop_workspace)

    log "Redistributing workspaces: external=$primary_external, internal=$internal_monitor, btop_workspace=$btop_workspace"

    # Get all workspaces
    local workspaces=($(hyprctl workspaces -j | jq -r '.[].id' | sort -n))

    for workspace in "${workspaces[@]}"; do
        if [ -n "$btop_workspace" ] && [ "$workspace" = "$btop_workspace" ]; then
            # btop workspace stays on internal monitor
            log "Keeping workspace $workspace (btop) on internal monitor $internal_monitor"
            hyprctl dispatch moveworkspacetomonitor "$workspace" "$internal_monitor"
        else
            # All other workspaces go to external monitor
            log "Moving workspace $workspace to external monitor $primary_external"
            hyprctl dispatch moveworkspacetomonitor "$workspace" "$primary_external"
        fi
    done

    # Focus the external monitor (where most work happens)
    hyprctl dispatch focusmonitor "$primary_external"
}

# Interactive monitor configuration
interactive_config() {
    while true; do
        local monitors_info=$(get_monitors_info)
        local monitor_count=$(echo "$monitors_info" | jq length)
        
        echo -e "${BLUE}=== Multi-Monitor Configuration ===${NC}"
        echo "Detected $monitor_count monitor(s):"
        echo
        
        echo "$monitors_info" | jq -r '.[] | "  \(.name): \(.width)x\(.height)@\(.refreshRate)Hz (\(.make) \(.model))"'
        echo
        
        echo "Available actions:"
        echo "1) Auto-configure monitors"
        echo "2) Configure specific monitor resolution"
        echo "3) Setup lid behavior (laptop only)"
        echo "4) Redistribute workspaces"
        echo "5) Show current configuration"
        echo "6) Exit"
        echo
        
        read -p "Select an option (1-6): " choice
        
        case $choice in
            1)
                generate_monitor_config
                hyprctl reload
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
            2)
                configure_specific_monitor
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
            3)
                configure_lid_behavior
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
            4)
                redistribute_workspaces
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
            5)
                show_current_config
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
            6)
                exit 0
                ;;
            *)
                error "Invalid option"
                echo
                read -p "Press Enter to continue..."
                clear
                ;;
        esac
    done
}

# Configure specific monitor resolution
configure_specific_monitor() {
    local monitors=($(hyprctl monitors -j | jq -r '.[].name'))
    
    echo "Available monitors:"
    for i in "${!monitors[@]}"; do
        echo "$((i+1))) ${monitors[$i]}"
    done
    echo
    
    read -p "Select monitor number: " monitor_num
    
    if [ "$monitor_num" -lt 1 ] || [ "$monitor_num" -gt "${#monitors[@]}" ]; then
        error "Invalid monitor selection"
        return 1
    fi
    
    local selected_monitor="${monitors[$((monitor_num-1))]}"
    local available_modes=($(hyprctl monitors -j | jq -r ".[] | select(.name == \"$selected_monitor\") | .availableModes[]"))
    
    echo "Available modes for $selected_monitor:"
    for i in "${!available_modes[@]}"; do
        echo "$((i+1))) ${available_modes[$i]}"
    done
    echo "$((${#available_modes[@]}+1))) Enter custom resolution"
    echo
    
    read -p "Select mode number (1-$((${#available_modes[@]}+1))): " mode_choice
    
    local resolution=""
    if [ "$mode_choice" -ge 1 ] && [ "$mode_choice" -le "${#available_modes[@]}" ]; then
        resolution="${available_modes[$((mode_choice-1))]}"
    elif [ "$mode_choice" -eq "$((${#available_modes[@]}+1))" ]; then
        read -p "Enter custom resolution (e.g., 1920x1080@60): " resolution
    else
        error "Invalid mode selection"
        return 1
    fi
    
    if [ -n "$resolution" ]; then
        # Get current monitor position to maintain it
        local current_x=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$selected_monitor\") | .x")
        local current_y=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$selected_monitor\") | .y")
        local position="${current_x}x${current_y}"
        
        log "Setting $selected_monitor to $resolution at position $position"
        hyprctl keyword monitor "$selected_monitor,$resolution,$position,1"
        
        if [ $? -eq 0 ]; then
            log "Resolution updated for $selected_monitor to $resolution"
            
            # Send notification if available
            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Monitor Configuration" "$selected_monitor set to $resolution" -t 3000
            fi
        else
            error "Failed to update monitor resolution"
        fi
    fi
}

# Show current configuration
show_current_config() {
    echo -e "${BLUE}=== Current Monitor Configuration ===${NC}"
    echo
    
    local device_type=$(detect_device_type)
    echo "Device Type: $device_type"
    echo
    
    echo "Active Monitors:"
    hyprctl monitors -j | jq -r '.[] | "  \(.name): \(.width)x\(.height)@\(.refreshRate)Hz (Position: \(.x),\(.y)) [Focus: \(.focused)]"'
    echo
    
    if [ "$device_type" = "laptop" ]; then
        echo "Laptop Status:"
        if is_lid_closed; then
            echo "  Lid: Closed"
        else
            echo "  Lid: Open"
        fi
        
        if is_ac_connected; then
            echo "  AC Power: Connected"
        else
            echo "  AC Power: Disconnected"
        fi
        echo
    fi
    
    echo "Workspace Distribution:"
    hyprctl workspaces -j | jq -r '.[] | "  Workspace \(.id): Monitor \(.monitor)"'
}

# Main function (wrapped in flock for mutual exclusion with hotplug/lid handler)
(
    if ! flock -w 30 200; then
        error "Could not acquire lock after 30s, another instance is running"
        exit 1
    fi

    case "${1:-}" in
        "auto")
            generate_monitor_config
            hyprctl reload
            ;;
        "lid")
            handle_lid_event
            ;;
        "setup")
            configure_lid_behavior
            generate_monitor_config
            hyprctl reload
            ;;
        "redistribute")
            redistribute_workspaces
            ;;
        "status")
            show_current_config
            ;;
        *)
            interactive_config
            ;;
    esac
) 200>"$LOCKFILE"
