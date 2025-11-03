#!/bin/bash

# Monitor Hotplug Detection Script for AGS Multi-Monitor Support
# Automatically restarts AGS and reloads hyperpaper when monitors are connected/disconnected

SCRIPT_DIR="$(dirname "$0")"
HYPR_DIR="$HOME/.config/hypr"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"
HYPERPAPER_RELOAD="$HYPR_DIR/hyprpaper/reload.sh"
WORKSPACE_STATE_MANAGER="$SCRIPT_DIR/workspace-state-manager.sh"
LOG_FILE="/tmp/hyprland-monitor-hotplug.log"
STATE_FILE="/tmp/hyprland-monitor-state"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get current monitor configuration
get_monitor_state() {
    local state
    # Try to get monitor state, handle jq parse errors gracefully
    state=$(hyprctl monitors -j 2>/dev/null | jq -r 'sort_by(.name) | map(.name) | join(",")' 2>/dev/null)
    
    # If jq fails or returns empty, try a simpler approach
    if [ -z "$state" ] || [ $? -ne 0 ]; then
        state=$(hyprctl monitors | awk '/Monitor/ {print $2}' | sort | tr '\n' ',' | sed 's/,$//')
    fi
    
    echo "$state"
}

# Restart AGS safely
restart_ags() {
    log "Restarting AGS due to monitor configuration change"
    
    # Kill existing AGS and related processes more aggressively
    pkill -9 -f "ags" 2>/dev/null || true
    pkill -9 -f "astal" 2>/dev/null || true
    
    # Also kill any stale gjs processes from AGS
    pgrep -f "gjs.*ags" | xargs -r kill -9 2>/dev/null || true
    
    # Wait for cleanup
    sleep 2
    
    # Verify processes are dead
    if pgrep -x "ags" > /dev/null; then
        log "Warning: AGS processes still running, forcing kill"
        pkill -9 "ags" 2>/dev/null || true
        sleep 1
    fi
    
    # Restart AGS
    log "Starting AGS"
    ags run --gtk 3 --log-file /tmp/ags.log >> "$LOG_FILE" 2>&1 &
    
    # Give it a moment to start
    sleep 1
    
    # Verify AGS started
    if pgrep -x "ags" > /dev/null; then
        log "AGS restarted successfully (PID: $(pgrep -x ags))"
    else
        log "ERROR: AGS failed to start"
    fi
}

# Reload hyperpaper safely
reload_hyperpaper() {
    log "Reloading hyperpaper due to monitor configuration change"
    
    # Execute hyperpaper reload script
    if [ -x "$HYPERPAPER_RELOAD" ]; then
        bash "$HYPERPAPER_RELOAD" >> "$LOG_FILE" 2>&1 &
        log "Hyperpaper reload initiated"
    else
        log "Warning: Hyperpaper reload script not found or not executable: $HYPERPAPER_RELOAD"
    fi
}

# Save workspace state before monitor changes
save_workspace_state() {
    log "Saving workspace state before monitor change"
    
    if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
        "$WORKSPACE_STATE_MANAGER" save >> "$LOG_FILE" 2>&1
        log "Workspace state saved"
    else
        log "Warning: Workspace state manager not found or not executable: $WORKSPACE_STATE_MANAGER"
    fi
}

# Restore workspace state after monitor changes
restore_workspace_state() {
    log "Restoring workspace state after monitor change"
    
    if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
        # Use auto-restore which only restores if state is recent
        "$WORKSPACE_STATE_MANAGER" auto-restore >> "$LOG_FILE" 2>&1
        log "Workspace state restoration attempted"
    else
        log "Warning: Workspace state manager not found or not executable: $WORKSPACE_STATE_MANAGER"
    fi
}

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    get_monitor_state > "$STATE_FILE"
    log "Initialized monitor state: $(cat "$STATE_FILE")"
fi

# Monitor for changes
monitor_changes() {
    log "Starting monitor hotplug detection"
    
    while true; do
        current_state=$(get_monitor_state)
        previous_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")
        
        if [ "$current_state" != "$previous_state" ]; then
            log "Monitor configuration changed:"
            log "  Previous: $previous_state"
            log "  Current:  $current_state"
            
            # Save workspace state BEFORE making changes
            save_workspace_state
            
            # Update state file
            echo "$current_state" > "$STATE_FILE"
            
            # Wait a moment for monitor setup to stabilize
            sleep 2
            
            # Run multi-monitor auto-configuration first
            if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
                log "Running multi-monitor auto-configuration"
                "$MULTI_MONITOR_SCRIPT" auto >> "$LOG_FILE" 2>&1
            fi
            
            # Wait for monitor configuration to apply
            sleep 1
            
            # Restart AGS
            restart_ags
            
            # Reload hyperpaper
            reload_hyperpaper
            
            # Wait for everything to settle, then restore workspace state
            sleep 2
            restore_workspace_state
        fi
        
        # Check every 2 seconds
        sleep 2
    done
}

# Handle different modes
case "${1:-}" in
    "monitor")
        monitor_changes
        ;;
    "restart-ags")
        restart_ags
        ;;
    "reload-hyperpaper")
        reload_hyperpaper
        ;;
    "reload-all")
        restart_ags
        sleep 1
        reload_hyperpaper
        ;;
    "check")
        current_state=$(get_monitor_state)
        echo "Current monitor state: $current_state"
        ;;
    "save-workspace")
        save_workspace_state
        ;;
    "restore-workspace")
        restore_workspace_state
        ;;
    *)
        echo "Monitor Hotplug Detection Script"
        echo "Usage: $0 [monitor|restart-ags|reload-hyperpaper|reload-all|check|save-workspace|restore-workspace]"
        echo "  monitor           - Start monitoring for hotplug events"
        echo "  restart-ags       - Restart AGS immediately"
        echo "  reload-hyperpaper - Reload hyperpaper immediately"
        echo "  reload-all        - Restart AGS and reload hyperpaper"
        echo "  check             - Check current monitor state"
        echo "  save-workspace    - Save current workspace layout manually"
        echo "  restore-workspace - Restore workspace layout manually"
        ;;
esac
