#!/bin/bash

# Refresh Rate Manager for External Monitors
# Dynamically detects and switches between available refresh rates
# Author: ArchEclipse Rice Configuration

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

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get external monitors (non-eDP)
get_external_monitors() {
    hyprctl monitors -j | jq -r '.[] | select(.name | startswith("eDP") | not) | .name'
}

# Get available refresh rates for a monitor
get_available_refresh_rates() {
    local monitor="$1"
    if [ -z "$monitor" ]; then
        return 1
    fi
    
    # Get available modes and extract unique refresh rates
    hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .availableModes[]" | \
    grep -oE '[0-9]+\.[0-9]+Hz$' | sed 's/Hz$//' | sort -n | uniq
}

# Get current refresh rate for a monitor
get_current_refresh_rate() {
    local monitor="$1"
    hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .refreshRate"
}

# Get monitor resolution
get_monitor_resolution() {
    local monitor="$1"
    local width=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .width")
    local height=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .height")
    echo "${width}x${height}"
}

# Get monitor position
get_monitor_position() {
    local monitor="$1"
    local x=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .x")
    local y=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .y")
    echo "${x}x${y}"
}

# Set refresh rate for a monitor
set_refresh_rate() {
    local monitor="$1"
    local refresh_rate="$2"
    local resolution=$(get_monitor_resolution "$monitor")
    local position=$(get_monitor_position "$monitor")
    
    log "Setting $monitor to ${resolution}@${refresh_rate}Hz at position $position"
    
    hyprctl keyword monitor "$monitor,${resolution}@${refresh_rate},${position},1"
    
    if [ $? -eq 0 ]; then
        log "Successfully updated $monitor refresh rate to ${refresh_rate}Hz"
        
        # Send notification
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Monitor Refresh Rate" "$monitor set to ${refresh_rate}Hz" -t 3000
        fi
    else
        error "Failed to update $monitor refresh rate"
    fi
}

# Cycle to next available refresh rate
cycle_refresh_rate() {
    local monitor="$1"
    
    if [ -z "$monitor" ]; then
        error "No monitor specified"
        return 1
    fi
    
    local current_rate=$(get_current_refresh_rate "$monitor")
    local available_rates=($(get_available_refresh_rates "$monitor"))
    
    if [ ${#available_rates[@]} -eq 0 ]; then
        error "No available refresh rates found for $monitor"
        return 1
    fi
    
    log "Current refresh rate for $monitor: ${current_rate}Hz"
    log "Available rates: ${available_rates[*]}"
    
    # Find current rate index
    local current_index=-1
    for i in "${!available_rates[@]}"; do
        if [ "${available_rates[$i]}" = "$current_rate" ]; then
            current_index=$i
            break
        fi
    done
    
    # Get next rate (cycle to beginning if at end)
    local next_index=0
    if [ "$current_index" -ge 0 ]; then
        next_index=$(( (current_index + 1) % ${#available_rates[@]} ))
    fi
    
    local next_rate="${available_rates[$next_index]}"
    set_refresh_rate "$monitor" "$next_rate"
}

# Interactive refresh rate selection
interactive_selection() {
    local external_monitors=($(get_external_monitors))
    
    if [ ${#external_monitors[@]} -eq 0 ]; then
        error "No external monitors detected"
        return 1
    fi
    
    echo -e "${BLUE}=== Refresh Rate Manager ===${NC}"
    echo
    
    # If only one external monitor, use it directly
    local selected_monitor=""
    if [ ${#external_monitors[@]} -eq 1 ]; then
        selected_monitor="${external_monitors[0]}"
        log "Using external monitor: $selected_monitor"
    else
        echo "Available external monitors:"
        for i in "${!external_monitors[@]}"; do
            local monitor="${external_monitors[$i]}"
            local current_rate=$(get_current_refresh_rate "$monitor")
            local resolution=$(get_monitor_resolution "$monitor")
            echo "$((i+1))) $monitor (${resolution}@${current_rate}Hz)"
        done
        echo
        
        read -p "Select monitor (1-${#external_monitors[@]}): " monitor_choice
        
        if [ "$monitor_choice" -lt 1 ] || [ "$monitor_choice" -gt "${#external_monitors[@]}" ]; then
            error "Invalid monitor selection"
            return 1
        fi
        
        selected_monitor="${external_monitors[$((monitor_choice-1))]}"
    fi
    
    local available_rates=($(get_available_refresh_rates "$selected_monitor"))
    local current_rate=$(get_current_refresh_rate "$selected_monitor")
    
    echo
    echo "Monitor: $selected_monitor"
    echo "Current refresh rate: ${current_rate}Hz"
    echo
    echo "Available refresh rates:"
    for i in "${!available_rates[@]}"; do
        local rate="${available_rates[$i]}"
        local marker=""
        if [ "$rate" = "$current_rate" ]; then
            marker=" (current)"
        fi
        echo "$((i+1))) ${rate}Hz${marker}"
    done
    echo "$((${#available_rates[@]}+1))) Cycle to next rate"
    echo "$((${#available_rates[@]}+2))) Exit"
    echo
    
    read -p "Select refresh rate: " rate_choice
    
    if [ "$rate_choice" -eq "$((${#available_rates[@]}+1))" ]; then
        cycle_refresh_rate "$selected_monitor"
    elif [ "$rate_choice" -eq "$((${#available_rates[@]}+2))" ]; then
        exit 0
    elif [ "$rate_choice" -ge 1 ] && [ "$rate_choice" -le "${#available_rates[@]}" ]; then
        local selected_rate="${available_rates[$((rate_choice-1))]}"
        set_refresh_rate "$selected_monitor" "$selected_rate"
    else
        error "Invalid selection"
    fi
}

# Show current status
show_status() {
    local external_monitors=($(get_external_monitors))
    
    echo -e "${BLUE}=== Monitor Refresh Rate Status ===${NC}"
    echo
    
    if [ ${#external_monitors[@]} -eq 0 ]; then
        echo "No external monitors detected"
        return 0
    fi
    
    for monitor in "${external_monitors[@]}"; do
        local current_rate=$(get_current_refresh_rate "$monitor")
        local resolution=$(get_monitor_resolution "$monitor")
        local position=$(get_monitor_position "$monitor")
        local available_rates=($(get_available_refresh_rates "$monitor"))
        
        echo "Monitor: $monitor"
        echo "  Resolution: $resolution"
        echo "  Position: $position"
        echo "  Current Rate: ${current_rate}Hz"
        echo "  Available Rates: ${available_rates[*]}Hz"
        echo
    done
}

# Main function
main() {
    case "${1:-}" in
        "cycle")
            local external_monitors=($(get_external_monitors))
            if [ ${#external_monitors[@]} -eq 1 ]; then
                cycle_refresh_rate "${external_monitors[0]}"
            else
                interactive_selection
            fi
            ;;
        "status")
            show_status
            ;;
        "set")
            if [ -z "$2" ] || [ -z "$3" ]; then
                error "Usage: $0 set <monitor> <refresh_rate>"
                exit 1
            fi
            set_refresh_rate "$2" "$3"
            ;;
        *)
            interactive_selection
            ;;
    esac
}

# Run main function with all arguments
main "$@"
