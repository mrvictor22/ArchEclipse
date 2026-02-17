#!/bin/bash
#
# fix-zen-cpufreq-service.sh
# Fixes the auto-cpufreq.service to point to the correct zen-cpufreq paths
# Run with: sudo bash ~/.config/hypr/scripts/fix-zen-cpufreq-service.sh
#

set -euo pipefail

SERVICE_FILE="/etc/systemd/system/auto-cpufreq.service"
ZEN_PATH="/opt/zen-cpufreq"

echo "=== zen-cpufreq Service Fix ==="
echo ""

# Verify zen-cpufreq installation
if [[ ! -d "$ZEN_PATH/venv/bin" ]]; then
    echo "ERROR: zen-cpufreq not found at $ZEN_PATH"
    exit 1
fi

echo "[1/4] Verified zen-cpufreq at $ZEN_PATH"
echo "       Version: $(sudo -u alphonse zen-cpufreq --version 2>&1 | grep 'auto-cpufreq version' || echo 'unknown')"

# Write corrected service file
echo "[2/4] Writing corrected service file..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=auto-cpufreq (zen-cpufreq) - Automatic CPU speed & power optimizer for Linux
After=multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/zen-cpufreq/venv
Environment=PYTHONPATH=/opt/zen-cpufreq
ExecStart=/opt/zen-cpufreq/venv/bin/python /opt/zen-cpufreq/venv/bin/auto-cpufreq --daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "       Written: $SERVICE_FILE"

# Reload and restart
echo "[3/4] Reloading systemd daemon..."
systemctl daemon-reload

echo "[4/4] Restarting auto-cpufreq.service..."
systemctl restart auto-cpufreq.service

echo ""
echo "=== Result ==="
systemctl status auto-cpufreq.service --no-pager | head -10
echo ""
echo "=== Current Power Profile ==="
cat /sys/firmware/acpi/platform_profile
echo ""
echo "Done! zen-cpufreq daemon is now running."
