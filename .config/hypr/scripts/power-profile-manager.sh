#!/bin/bash
#
# power-profile-manager.sh
# Automatically manages power profiles based on AC/battery status
#

PROFILE_FILE="/sys/firmware/acpi/platform_profile"
AC_STATUS_FILE="/sys/class/power_supply/AC0/online"

# Configuration - edit these as needed
AC_PROFILE="performance"      # Profile when on AC power
BATTERY_PROFILE="balanced"    # Profile when on battery
THERMAL_LIMIT_AC=95           # Thermal limit on AC (°C)
THERMAL_LIMIT_BATTERY=85      # Thermal limit on battery (°C)
GPU_PERF_AC="high"            # GPU performance on AC (auto, low, high)
GPU_PERF_BATTERY="auto"       # GPU performance on battery

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    logger -t power-profile-manager "$1"
}

# Check if platform_profile is available
if [[ ! -f "$PROFILE_FILE" ]]; then
    log "ERROR: platform_profile not available on this system"
    exit 1
fi

# Get current AC status
get_ac_status() {
    if [[ -f "$AC_STATUS_FILE" ]]; then
        cat "$AC_STATUS_FILE"
    else
        # Try alternative paths
        for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
            if [[ -f "$ac" ]]; then
                cat "$ac"
                return
            fi
        done
        echo "1"  # Default to AC if unknown
    fi
}

# Get current profile
get_current_profile() {
    cat "$PROFILE_FILE" 2>/dev/null
}

# Set platform profile
set_profile() {
    local profile="$1"
    local current=$(get_current_profile)

    if [[ "$current" == "$profile" ]]; then
        log "Profile already set to $profile"
        return 0
    fi

    echo "$profile" > "$PROFILE_FILE" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "Profile changed: $current -> $profile"
        return 0
    else
        log "ERROR: Failed to set profile to $profile"
        return 1
    fi
}

# Set thermal limit via ryzenadj
set_thermal_limit() {
    local limit="$1"
    if command -v ryzenadj &>/dev/null; then
        ryzenadj --tctl-temp="$limit" &>/dev/null
        if [[ $? -eq 0 ]]; then
            log "Thermal limit set to ${limit}°C"
        fi
    fi
}

# Set GPU performance level
set_gpu_performance() {
    local level="$1"

    # Find the correct GPU device
    for gpu_file in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        if [[ -f "$gpu_file" ]]; then
            echo "$level" > "$gpu_file" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log "GPU performance set to $level ($gpu_file)"
            else
                log "WARNING: Failed to set GPU performance to $level"
            fi
            return
        fi
    done
    log "WARNING: No GPU power control found"
}

# Apply profile based on AC status
apply_profile() {
    local ac_status=$(get_ac_status)

    if [[ "$ac_status" == "1" ]]; then
        log "AC Power detected"
        set_profile "$AC_PROFILE"
        set_thermal_limit "$THERMAL_LIMIT_AC"
        set_gpu_performance "$GPU_PERF_AC"
    else
        log "Battery Power detected"
        set_profile "$BATTERY_PROFILE"
        set_thermal_limit "$THERMAL_LIMIT_BATTERY"
        set_gpu_performance "$GPU_PERF_BATTERY"
    fi
}

# Main
case "${1:-auto}" in
    auto)
        apply_profile
        ;;
    ac)
        log "Forcing AC profile"
        set_profile "$AC_PROFILE"
        set_thermal_limit "$THERMAL_LIMIT_AC"
        ;;
    battery)
        log "Forcing battery profile"
        set_profile "$BATTERY_PROFILE"
        set_thermal_limit "$THERMAL_LIMIT_BATTERY"
        ;;
    performance|balanced|low-power)
        set_profile "$1"
        ;;
    status)
        echo "AC Status: $(get_ac_status)"
        echo "Current Profile: $(get_current_profile)"
        echo "Available Profiles: $(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null)"
        ;;
    *)
        echo "Usage: $0 {auto|ac|battery|performance|balanced|low-power|status}"
        exit 1
        ;;
esac
