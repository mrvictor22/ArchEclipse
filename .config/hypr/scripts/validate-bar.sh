#!/bin/bash

# Bar Validation Script
# Validates that AGS bar is correctly displayed after monitor changes
# Restarts AGS if the bar is not properly configured

LOG_FILE="/tmp/hyprland-bar-validation.log"
MAX_RETRIES=3
RETRY_DELAY=2

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Get current monitors from Hyprland
get_monitors() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null | sort
}

# Get monitors that have AGS bars (via hyprctl layers)
get_bar_monitors() {
    hyprctl layers -j 2>/dev/null | jq -r 'to_entries[] | select(.value.levels."2"[]?.namespace == "bar") | .key' 2>/dev/null | sort
}

# Check if AGS is running
is_ags_running() {
    pgrep -f "ags run" > /dev/null 2>&1 || pgrep -x "gjs" > /dev/null 2>&1
}

# Check bar width matches monitor width
validate_bar_geometry() {
    local monitor_name="$1"

    # Get monitor width from Hyprland
    local monitor_width=$(hyprctl monitors -j 2>/dev/null | jq -r ".[] | select(.name == \"$monitor_name\") | .width" 2>/dev/null)

    if [ -z "$monitor_width" ] || [ "$monitor_width" = "null" ]; then
        warn "Could not get width for monitor $monitor_name"
        return 1
    fi

    # Get bar geometry from hyprctl layers
    local bar_info=$(hyprctl layers -j 2>/dev/null | jq -r ".[\"$monitor_name\"].levels.\"2\"[] | select(.namespace == \"bar\")" 2>/dev/null)

    if [ -z "$bar_info" ]; then
        warn "No bar found on monitor $monitor_name"
        return 1
    fi

    local bar_width=$(echo "$bar_info" | jq -r '.w' 2>/dev/null)

    if [ -z "$bar_width" ] || [ "$bar_width" = "null" ]; then
        warn "Could not get bar width for monitor $monitor_name"
        return 1
    fi

    # Allow small margin difference (bars have margins)
    local margin=20
    local min_expected=$((monitor_width - margin))

    if [ "$bar_width" -lt "$min_expected" ]; then
        error "Bar width ($bar_width) is less than expected (min: $min_expected) on monitor $monitor_name"
        return 1
    fi

    log "Bar geometry OK on $monitor_name: bar_width=$bar_width, monitor_width=$monitor_width"
    return 0
}

# Main validation function
validate_bars() {
    local all_valid=true

    # Check if AGS is running
    if ! is_ags_running; then
        error "AGS is not running"
        return 1
    fi

    # Get all active monitors
    local monitors=$(get_monitors)

    if [ -z "$monitors" ]; then
        error "No monitors detected"
        return 1
    fi

    log "Validating bars for monitors: $(echo $monitors | tr '\n' ' ')"

    # Check each monitor has a bar with correct geometry
    for monitor in $monitors; do
        if ! validate_bar_geometry "$monitor"; then
            all_valid=false
        fi
    done

    if [ "$all_valid" = true ]; then
        log "All bars validated successfully"
        return 0
    else
        return 1
    fi
}

# Restart AGS safely
restart_ags() {
    log "Restarting AGS..."

    # First try graceful quit
    ags quit 2>/dev/null || true
    sleep 1

    # Kill existing AGS processes
    pkill -9 -f "ags" 2>/dev/null || true
    pkill -9 -f "astal" 2>/dev/null || true
    killall gjs 2>/dev/null || true

    sleep 1

    # Verify processes are dead
    if pgrep -f "ags" > /dev/null || pgrep -x "gjs" > /dev/null; then
        warn "Processes still running, forcing kill..."
        pkill -9 -f "ags" 2>/dev/null || true
        pkill -9 -f "gjs" 2>/dev/null || true
        sleep 1
    fi

    # Start AGS with explicit GTK version
    log "Starting AGS..."
    ags run --log-file /tmp/ags.log >> "$LOG_FILE" 2>&1 &

    # Wait for AGS to initialize
    sleep 3

    if is_ags_running; then
        log "AGS restarted successfully"
        return 0
    else
        error "Failed to restart AGS"
        return 1
    fi
}

# Validate with retries and auto-fix
validate_with_retry() {
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log "Validation attempt $attempt/$MAX_RETRIES"

        if validate_bars; then
            log "Validation successful on attempt $attempt"
            return 0
        fi

        if [ $attempt -lt $MAX_RETRIES ]; then
            warn "Validation failed, restarting AGS and retrying..."
            restart_ags
            sleep $RETRY_DELAY
        fi

        attempt=$((attempt + 1))
    done

    error "Validation failed after $MAX_RETRIES attempts"
    notify-send -u critical "Bar Validation Failed" "AGS bar could not be properly configured after $MAX_RETRIES attempts" 2>/dev/null || true
    return 1
}

# Show status
show_status() {
    echo "=== Bar Validation Status ==="
    echo ""

    echo "AGS Status: $(is_ags_running && echo "Running (PID: $(pgrep -x ags))" || echo "NOT RUNNING")"
    echo ""

    echo "Monitors:"
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | "  \(.name): \(.width)x\(.height)"' 2>/dev/null
    echo ""

    echo "Bar Layers:"
    for monitor in $(get_monitors); do
        local bar_info=$(hyprctl layers -j 2>/dev/null | jq -r ".[\"$monitor\"].levels.\"2\"[] | select(.namespace == \"bar\")" 2>/dev/null)
        if [ -n "$bar_info" ]; then
            local w=$(echo "$bar_info" | jq -r '.w')
            local h=$(echo "$bar_info" | jq -r '.h')
            local x=$(echo "$bar_info" | jq -r '.x')
            local y=$(echo "$bar_info" | jq -r '.y')
            echo "  $monitor: ${w}x${h} at ($x,$y)"
        else
            echo "  $monitor: NO BAR FOUND"
        fi
    done
    echo ""

    echo "Validation Result:"
    if validate_bars 2>/dev/null; then
        echo "  ✓ All bars OK"
    else
        echo "  ✗ Validation FAILED"
    fi
}

# Handle commands
case "${1:-}" in
    "validate")
        validate_bars
        exit $?
        ;;
    "validate-retry"|"fix")
        validate_with_retry
        exit $?
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart_ags
        ;;
    *)
        echo "Bar Validation Script"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  validate       - Check if bars are correctly configured"
        echo "  validate-retry - Validate with auto-restart on failure (max $MAX_RETRIES attempts)"
        echo "  fix            - Alias for validate-retry"
        echo "  status         - Show detailed status information"
        echo "  restart        - Force restart AGS"
        ;;
esac
