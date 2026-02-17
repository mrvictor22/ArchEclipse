#!/bin/bash
#
# setup-power-sudoers.sh
# Creates a sudoers rule to allow power-mode.sh without password
# Run with: sudo bash ~/.config/hypr/scripts/setup-power-sudoers.sh
#

set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/power-mode"
USER="alphonse"
SCRIPT="/home/${USER}/.config/hypr/scripts/power-mode.sh"

echo "=== Power Mode Sudoers Setup ==="
echo ""

cat > "$SUDOERS_FILE" << EOF
# Allow $USER to run power-mode.sh without password (for AGS PowerWidget)
$USER ALL=(root) NOPASSWD: $SCRIPT
EOF

chmod 440 "$SUDOERS_FILE"

# Validate
if visudo -cf "$SUDOERS_FILE" &>/dev/null; then
    echo "Written and validated: $SUDOERS_FILE"
    echo ""
    cat "$SUDOERS_FILE"
    echo ""
    echo "Testing: sudo $SCRIPT status"
    sudo -u "$USER" sudo "$SCRIPT" status
    echo ""
    echo "Done! PowerWidget can now change modes without password prompts."
else
    echo "ERROR: Invalid sudoers syntax, removing file"
    rm -f "$SUDOERS_FILE"
    exit 1
fi
