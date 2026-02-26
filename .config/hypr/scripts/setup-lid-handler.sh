#!/bin/bash

# Setup script for lid handler - requires root
# Run with: sudo bash ~/.config/hypr/scripts/setup-lid-handler.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Este script necesita root. Ejecuta: sudo $0"
    exit 1
fi

echo "=== Configurando lid handler ==="

# 1. logind: ignorar cierre de tapa (Hyprland lo maneja)
echo "[1/3] Configurando logind para ignorar lid switch..."
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-hyprland-lid.conf << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
# NO reiniciar logind aquí - mata la sesión de Hyprland
# El cambio aplica en el próximo reboot/login
echo "      OK (aplica en próximo reboot)"

# 2. Instalar acpid (provee acpi_listen para detección instantánea de lid)
echo "[2/3] Instalando acpid..."
if command -v acpi_listen &>/dev/null; then
    echo "      Ya instalado"
else
    pacman -S --noconfirm acpid
    echo "      OK"
fi

# 3. Reiniciar servicio del usuario
echo "[3/3] Reiniciando hyprland-lid-handler.service..."
REAL_USER="${SUDO_USER:-$USER}"
REAL_UID=$(id -u "$REAL_USER")
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user restart hyprland-lid-handler.service
echo "      OK"

echo ""
echo "=== Listo. Cierra la tapa para probar ==="
