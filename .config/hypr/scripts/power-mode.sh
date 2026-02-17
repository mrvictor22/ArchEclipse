#!/bin/bash
#
# power-mode.sh - Unified power mode management for zen-cpufreq + ACPI
# Used by AGS PowerWidget to read status and change modes
#

PROFILE_FILE="/sys/firmware/acpi/platform_profile"
GOVERNOR_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
EPP_FILE="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
BOOST_FILE="/sys/devices/system/cpu/cpufreq/boost"
CUR_FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
MAX_FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"

# Read helpers (safe reads)
read_file() { cat "$1" 2>/dev/null || echo "$2"; }

get_cpu_temp() {
    local temp
    temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
    if [[ -n "$temp" ]]; then
        echo $(( temp / 1000 ))
    else
        echo "0"
    fi
}

get_ac_status() {
    for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        if [[ -f "$ac" ]]; then
            cat "$ac"
            return
        fi
    done
    echo "1"
}

get_auto_cpufreq_mode() {
    # Check if auto-cpufreq is forcing a mode
    if systemctl is-active auto-cpufreq.service &>/dev/null; then
        # auto-cpufreq doesn't expose force mode easily, infer from governor+EPP
        local gov=$(read_file "$GOVERNOR_FILE" "unknown")
        local epp=$(read_file "$EPP_FILE" "unknown")

        if [[ "$gov" == "performance" && "$epp" == "performance" ]]; then
            echo "performance"
        elif [[ "$gov" == "powersave" && ("$epp" == "power" || "$epp" == "balance_power") ]]; then
            echo "power-saver"
        else
            echo "auto"
        fi
    else
        echo "inactive"
    fi
}

# Output full status as JSON (for AGS widget)
status_json() {
    local profile=$(read_file "$PROFILE_FILE" "unknown")
    local governor=$(read_file "$GOVERNOR_FILE" "unknown")
    local epp=$(read_file "$EPP_FILE" "unknown")
    local boost=$(read_file "$BOOST_FILE" "0")
    local cur_freq=$(read_file "$CUR_FREQ_FILE" "0")
    local max_freq=$(read_file "$MAX_FREQ_FILE" "0")
    local cpu_temp=$(get_cpu_temp)
    local ac_status=$(get_ac_status)
    local mode=$(get_auto_cpufreq_mode)

    # Convert freq from kHz to MHz
    cur_freq=$(( cur_freq / 1000 ))
    max_freq=$(( max_freq / 1000 ))

    cat << EOF
{"profile":"$profile","governor":"$governor","epp":"$epp","boost":$boost,"curFreq":$cur_freq,"maxFreq":$max_freq,"cpuTemp":$cpu_temp,"acOnline":$ac_status,"mode":"$mode"}
EOF
}

# Set power mode (requires root via pkexec)
set_mode() {
    local mode="$1"

    case "$mode" in
        performance)
            echo "performance" > "$PROFILE_FILE" 2>/dev/null
            zen-cpufreq --force performance 2>/dev/null
            ;;
        balanced)
            echo "balanced" > "$PROFILE_FILE" 2>/dev/null
            zen-cpufreq --force reset 2>/dev/null
            ;;
        power-saver)
            echo "low-power" > "$PROFILE_FILE" 2>/dev/null
            zen-cpufreq --force powersave 2>/dev/null
            ;;
        *)
            echo "Unknown mode: $mode"
            exit 1
            ;;
    esac
    echo "Mode set to $mode"
}

# Set thermal limit
set_thermal() {
    local limit="$1"
    if command -v ryzenadj &>/dev/null; then
        ryzenadj --tctl-temp="$limit" 2>&1
    else
        echo "ryzenadj not found"
        exit 1
    fi
}

# Main
case "${1:-status}" in
    status)
        status_json
        ;;
    set)
        set_mode "$2"
        ;;
    thermal)
        set_thermal "$2"
        ;;
    *)
        echo "Usage: $0 {status|set <performance|balanced|power-saver>|thermal <temp>}"
        exit 1
        ;;
esac
