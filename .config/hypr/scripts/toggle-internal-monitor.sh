#!/bin/bash
# Toggle internal monitor (eDP-1) on/off
# Used by Super+Shift+I keybind

INTERNAL_MONITOR="eDP-1"

# Check if internal monitor exists and is enabled
is_enabled=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$INTERNAL_MONITOR\") | .disabled | not")

if [ "$is_enabled" = "true" ]; then
    # Monitor is enabled, disable it
    hyprctl keyword monitor "$INTERNAL_MONITOR,disable"
    notify-send -t 2000 "Monitor Interno" "Desactivado"
elif [ "$is_enabled" = "false" ]; then
    # Monitor is disabled, enable it
    hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1"
    notify-send -t 2000 "Monitor Interno" "Activado"
else
    # Monitor not found in active list, try to enable it
    hyprctl keyword monitor "$INTERNAL_MONITOR,preferred,auto,1"
    notify-send -t 2000 "Monitor Interno" "Activado"
fi
