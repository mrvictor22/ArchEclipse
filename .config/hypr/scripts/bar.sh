#!/bin/bash

ags quit

killall gjs

# GDK_BACKEND=wayland required for gtk4-layer-shell to work properly
GDK_BACKEND=wayland ags run --gtk 3 --log-file /tmp/ags.log &
