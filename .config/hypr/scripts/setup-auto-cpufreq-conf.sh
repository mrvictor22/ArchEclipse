#!/bin/bash
#
# setup-auto-cpufreq-conf.sh
# Creates /etc/auto-cpufreq.conf with optimized settings for AMD laptop
# Run with: sudo bash ~/.config/hypr/scripts/setup-auto-cpufreq-conf.sh
#

set -euo pipefail

CONF_FILE="/etc/auto-cpufreq.conf"

echo "=== auto-cpufreq Configuration Setup ==="
echo ""

cat > "$CONF_FILE" << 'EOF'
# auto-cpufreq (zen-cpufreq) configuration
# Optimized for AMD laptop with Ryzen CPU
# Created: 2026-02-16

[charger]
# On AC power: prioritize performance
governor = performance
energy_performance_preference = performance
# auto = let auto-cpufreq decide when to boost
turbo = auto

[battery]
# On battery: prioritize efficiency
governor = powersave
energy_performance_preference = balance_power
# auto = allow turbo only when needed (brief bursts)
turbo = auto
EOF

echo "Written: $CONF_FILE"
echo ""
cat "$CONF_FILE"
echo ""

# Restart service to apply
echo "Restarting auto-cpufreq service..."
systemctl restart auto-cpufreq.service
echo ""
systemctl status auto-cpufreq.service --no-pager | head -5
echo ""
echo "Done!"
