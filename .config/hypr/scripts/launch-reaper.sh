#!/bin/bash
# REAPER XWayland Window Creation Fix
# Problem: REAPER occasionally starts as zombie - audio engine runs but GUI never appears
# Solution: Launch with window creation monitoring and auto-restart if needed

REAPER_BIN="/usr/lib/REAPER/reaper"
WINDOW_TIMEOUT=10  # iterations (0.5s each = 5 seconds total)
MAX_RETRIES=3
REAPER_ARGS="$@"  # Pass any arguments (like project files)

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

kill_reaper() {
    if pgrep -f "$REAPER_BIN" > /dev/null 2>&1; then
        log "Killing existing REAPER process..."
        pkill -9 -f "$REAPER_BIN"
        sleep 0.5
    fi
}

check_window_exists() {
    hyprctl clients -j | jq -e '.[] | select(.class == "REAPER" or .class == "reaper")' > /dev/null 2>&1
}

connect_audio_interface() {
    # Connect Behringer U-Phoria to REAPER inputs
    local behringer_in="alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input"
    local behringer_out="alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-output"

    # Wait for REAPER JACK ports to be available (up to 5 seconds)
    local wait=0
    while [ $wait -lt 10 ]; do
        if pw-link -i 2>/dev/null | grep -q "REAPER:in1"; then
            break
        fi
        sleep 0.5
        wait=$((wait + 1))
    done

    if ! pw-link -i 2>/dev/null | grep -q "REAPER:in1"; then
        log "REAPER JACK ports not available"
        return 1
    fi

    # Disconnect HyperX if connected
    pw-link -d "alsa_input.usb-HP__Inc_HyperX_QuadCast_S_4103-00.analog-stereo:capture_FL" "REAPER:in1" 2>/dev/null
    pw-link -d "alsa_input.usb-HP__Inc_HyperX_QuadCast_S_4103-00.analog-stereo:capture_FR" "REAPER:in2" 2>/dev/null

    if pw-link -o 2>/dev/null | grep -q "$behringer_in"; then
        pw-link "${behringer_in}:capture_FL" "REAPER:in1"
        pw-link "${behringer_in}:capture_FR" "REAPER:in2"
        pw-link "REAPER:out1" "${behringer_out}:playback_FL" 2>/dev/null
        pw-link "REAPER:out2" "${behringer_out}:playback_FR" 2>/dev/null
        log "Behringer U-Phoria connected to REAPER"
    else
        log "Behringer U-Phoria not found, skipping audio routing"
    fi
}

launch_reaper() {
    log "Launching REAPER with pw-jack..."
    pw-jack $REAPER_BIN $REAPER_ARGS &
    REAPER_PID=$!

    # Wait for window creation with timeout
    local elapsed=0
    while [ $elapsed -lt $WINDOW_TIMEOUT ]; do
        sleep 0.5
        elapsed=$((elapsed + 1))

        if check_window_exists; then
            log "REAPER window detected successfully!"
            return 0
        fi

        # Check if process died
        if ! kill -0 $REAPER_PID 2>/dev/null; then
            log "REAPER process died unexpectedly"
            return 1
        fi
    done

    # Timeout reached - process running but no window (zombie state)
    log "REAPER window not detected after ${WINDOW_TIMEOUT}s - zombie state"
    return 1
}

main() {
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log "Attempt $attempt of $MAX_RETRIES"

        kill_reaper

        if launch_reaper; then
            log "REAPER started successfully on attempt $attempt"
            connect_audio_interface
            exit 0
        fi

        log "Attempt $attempt failed"
        attempt=$((attempt + 1))
    done

    log "ERROR: Failed to start REAPER after $MAX_RETRIES attempts"
    notify-send -u critical "REAPER" "Failed to start after $MAX_RETRIES attempts"
    exit 1
}

main
