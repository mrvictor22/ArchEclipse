#!/bin/bash
FILE="/etc/sudoers.d/power-mode"
echo 'alphonse ALL=(root) NOPASSWD: /home/alphonse/.config/hypr/scripts/power-mode.sh' > "$FILE"
chmod 440 "$FILE"
echo "OK: sudoers creado"
cat "$FILE"
