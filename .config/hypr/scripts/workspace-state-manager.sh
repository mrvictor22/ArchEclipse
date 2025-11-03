#!/bin/bash

# Workspace State Manager for Hyprland
# Saves and restores window positions across monitor changes (KVM switch support)

STATE_DIR="$HOME/.cache/hypr/workspace-states"
CURRENT_STATE="$STATE_DIR/current-state.json"
LOG_FILE="/tmp/hyprland-workspace-state.log"

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get current workspace state (all windows with their workspaces)
get_workspace_state() {
    log "Capturing current workspace state..."
    
    # Get all clients (windows) with their workspace info
    local state=$(hyprctl clients -j 2>/dev/null | jq -c '[.[] | {
        address: .address,
        class: .class,
        title: .title,
        workspace: .workspace.id,
        monitor: .monitor,
        pid: .pid,
        initialClass: .initialClass,
        initialTitle: .initialTitle
    }]')
    
    if [ $? -eq 0 ] && [ -n "$state" ] && [ "$state" != "null" ]; then
        echo "$state"
        log "State captured: $(echo "$state" | jq length) windows"
        return 0
    else
        log "ERROR: Failed to capture workspace state"
        return 1
    fi
}

# Save current workspace state
save_state() {
    log "=== Saving workspace state ==="
    
    local state=$(get_workspace_state)
    
    if [ $? -eq 0 ] && [ -n "$state" ]; then
        echo "$state" > "$CURRENT_STATE"
        log "State saved successfully to $CURRENT_STATE"
        
        # Also create a backup with timestamp
        local backup="$STATE_DIR/backup-$(date +%s).json"
        echo "$state" > "$backup"
        
        # Keep only last 5 backups
        ls -t "$STATE_DIR"/backup-*.json 2>/dev/null | tail -n +6 | xargs -r rm
        
        return 0
    else
        log "ERROR: Failed to save workspace state"
        return 1
    fi
}

# Restore windows to their saved workspaces
restore_state() {
    log "=== Restoring workspace state ==="
    
    if [ ! -f "$CURRENT_STATE" ]; then
        log "No saved state found at $CURRENT_STATE"
        return 1
    fi
    
    # Wait a bit for monitor setup to stabilize
    sleep 2
    
    local saved_state=$(cat "$CURRENT_STATE")
    local current_windows=$(hyprctl clients -j 2>/dev/null)
    
    if [ -z "$saved_state" ] || [ -z "$current_windows" ]; then
        log "ERROR: Could not read state or current windows"
        return 1
    fi
    
    local restored=0
    local total=$(echo "$saved_state" | jq length)
    
    log "Attempting to restore $total windows..."
    
    # Iterate through saved state
    echo "$saved_state" | jq -c '.[]' | while read -r saved_window; do
        local saved_class=$(echo "$saved_window" | jq -r '.class')
        local saved_title=$(echo "$saved_window" | jq -r '.title')
        local saved_workspace=$(echo "$saved_window" | jq -r '.workspace')
        local saved_initial_class=$(echo "$saved_window" | jq -r '.initialClass')
        
        # Find matching window in current windows
        # Match by class and title, or by initialClass
        local current_address=$(echo "$current_windows" | jq -r --arg class "$saved_class" \
            --arg initial "$saved_initial_class" \
            '.[] | select(
                (.class == $class and .initialClass == $initial) or
                (.initialClass == $initial and $initial != "")
            ) | .address' | head -n 1)
        
        if [ -n "$current_address" ] && [ "$current_address" != "null" ]; then
            local current_workspace=$(echo "$current_windows" | jq -r \
                --arg addr "$current_address" \
                '.[] | select(.address == $addr) | .workspace.id')
            
            # Only move if workspace changed
            if [ "$current_workspace" != "$saved_workspace" ]; then
                log "Moving window: $saved_class (ws $current_workspace -> $saved_workspace)"
                hyprctl dispatch movetoworkspacesilent "$saved_workspace,address:$current_address" 2>&1 | head -n 2 >> "$LOG_FILE"
                restored=$((restored + 1))
                
                # Small delay between moves
                sleep 0.1
            else
                log "Window already in correct workspace: $saved_class (ws $saved_workspace)"
            fi
        else
            log "Could not find current window for: $saved_class"
        fi
    done
    
    log "Restoration complete. Attempted to restore windows."
    return 0
}

# Show current state (for debugging)
show_state() {
    if [ ! -f "$CURRENT_STATE" ]; then
        echo "No saved state found"
        return 1
    fi
    
    echo "=== Saved Workspace State ==="
    cat "$CURRENT_STATE" | jq -r '.[] | "Workspace \(.workspace): \(.class) - \(.title)"' | sort
}

# Show current live state
show_current() {
    echo "=== Current Live State ==="
    hyprctl clients -j | jq -r '.[] | "Workspace \(.workspace.id): \(.class) - \(.title)"' | sort
}

# Clear saved state
clear_state() {
    if [ -f "$CURRENT_STATE" ]; then
        rm "$CURRENT_STATE"
        log "Cleared saved state"
        echo "State cleared"
    else
        echo "No state to clear"
    fi
}

# Main command handler
case "${1:-}" in
    "save")
        save_state
        ;;
    "restore")
        restore_state
        ;;
    "show")
        show_state
        ;;
    "current")
        show_current
        ;;
    "clear")
        clear_state
        ;;
    "auto-restore")
        # Auto-restore mode: restore if state exists and is recent (within 10 minutes)
        if [ -f "$CURRENT_STATE" ]; then
            local state_age=$(($(date +%s) - $(stat -c %Y "$CURRENT_STATE" 2>/dev/null || echo 0)))
            if [ $state_age -lt 600 ]; then
                log "Auto-restore: State is recent (${state_age}s old), restoring..."
                restore_state
            else
                log "Auto-restore: State is too old (${state_age}s), skipping restore"
            fi
        else
            log "Auto-restore: No state found, skipping"
        fi
        ;;
    *)
        echo "Workspace State Manager for Hyprland"
        echo "Usage: $0 [save|restore|show|current|clear|auto-restore]"
        echo ""
        echo "Commands:"
        echo "  save         - Save current workspace state"
        echo "  restore      - Restore windows to saved workspaces"
        echo "  show         - Show saved state"
        echo "  current      - Show current live state"
        echo "  clear        - Clear saved state"
        echo "  auto-restore - Restore if state is recent (< 10 min)"
        echo ""
        echo "Integration with KVM:"
        echo "  Run 'save' before switching away with KVM"
        echo "  Run 'restore' after switching back"
        ;;
esac
