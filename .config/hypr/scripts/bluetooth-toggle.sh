#!/bin/bash
# bluetooth-toggle.sh - Manejo inteligente de Bluetooth con soporte para blacklist
# Resuelve bug de memory leak en Realtek RTL8852BU (0bda:4853)
# Documentado: 2026-02-02

BLACKLIST_FILE="/etc/modprobe.d/blacklist-realtek-bt.conf"
BLACKLIST_CONTENT="# Blacklist Realtek Bluetooth - causa memory leak en kworker threads
# Bug documentado: 2026-02-02
# Hardware: Realtek RTL8852BU (0bda:4853)
blacklist btusb
blacklist btrtl"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_status() {
    local bt_service=$(systemctl is-active bluetooth 2>/dev/null)
    local bt_module=$(lsmod | grep -q btusb && echo "loaded" || echo "unloaded")
    local bt_blacklisted=$([ -f "$BLACKLIST_FILE" ] && echo "true" || echo "false")
    local kworker_count=$(ps aux 2>/dev/null | grep -c "kworker.*+bt$" || echo "0")

    # Estado general
    local status="disabled"
    if [ "$bt_service" = "active" ] && [ "$bt_module" = "loaded" ]; then
        status="enabled"
    elif [ "$bt_module" = "loaded" ]; then
        status="partial"
    fi

    if [ "$1" = "json" ]; then
        echo "{\"status\":\"$status\",\"service\":\"$bt_service\",\"module\":\"$bt_module\",\"blacklisted\":$bt_blacklisted,\"kworkers\":$kworker_count}"
    else
        echo -e "Estado Bluetooth:"
        echo -e "  Servicio: ${bt_service}"
        echo -e "  Módulo btusb: ${bt_module}"
        echo -e "  Blacklisted: ${bt_blacklisted}"
        echo -e "  kworkers BT: ${kworker_count}"
        echo -e "  Estado general: ${status}"
    fi
}

enable_bluetooth() {
    echo -e "${GREEN}Activando Bluetooth...${NC}"

    # 1. Remover blacklist si existe
    if [ -f "$BLACKLIST_FILE" ]; then
        echo "Removiendo blacklist..."
        pkexec rm -f "$BLACKLIST_FILE" || {
            echo -e "${RED}Error: No se pudo remover blacklist${NC}"
            return 1
        }
    fi

    # 2. Cargar módulos
    echo "Cargando módulos..."
    pkexec modprobe btusb btrtl 2>/dev/null

    # 3. Iniciar servicio
    echo "Iniciando servicio bluetooth..."
    pkexec systemctl start bluetooth

    # 4. Verificar
    sleep 1
    if systemctl is-active bluetooth &>/dev/null; then
        echo -e "${GREEN}Bluetooth activado correctamente${NC}"
        notify-send "Bluetooth" "Activado correctamente" -i bluetooth-active 2>/dev/null
        return 0
    else
        echo -e "${RED}Error al activar Bluetooth${NC}"
        return 1
    fi
}

disable_bluetooth() {
    local permanent=${1:-false}

    echo -e "${YELLOW}Desactivando Bluetooth...${NC}"

    # 1. Detener servicio
    echo "Deteniendo servicio bluetooth..."
    pkexec systemctl stop bluetooth 2>/dev/null

    # 2. Descargar módulos
    echo "Descargando módulos..."
    pkexec modprobe -r btusb btrtl 2>/dev/null

    # 3. Crear blacklist si es permanente
    if [ "$permanent" = "true" ] || [ "$permanent" = "permanent" ]; then
        echo "Creando blacklist permanente..."
        echo "$BLACKLIST_CONTENT" | pkexec tee "$BLACKLIST_FILE" > /dev/null || {
            echo -e "${RED}Error: No se pudo crear blacklist${NC}"
        }
        echo -e "${YELLOW}Bluetooth desactivado permanentemente${NC}"
        notify-send "Bluetooth" "Desactivado permanentemente (no cargará en próximo boot)" -i bluetooth-disabled 2>/dev/null
    else
        echo -e "${GREEN}Bluetooth desactivado (temporal)${NC}"
        notify-send "Bluetooth" "Desactivado temporalmente" -i bluetooth-disabled 2>/dev/null
    fi

    # Verificar kworkers restantes
    local remaining=$(ps aux 2>/dev/null | grep -c "kworker.*+bt$")
    if [ "$remaining" -gt 2 ]; then
        echo -e "${YELLOW}Nota: Quedan $remaining kworkers BT. Se limpiarán gradualmente.${NC}"
    fi

    return 0
}

toggle_bluetooth() {
    local current_status=$(get_status json | jq -r '.status')

    if [ "$current_status" = "enabled" ] || [ "$current_status" = "partial" ]; then
        disable_bluetooth "$1"
    else
        enable_bluetooth
    fi
}

remove_blacklist() {
    if [ -f "$BLACKLIST_FILE" ]; then
        echo "Removiendo blacklist..."
        pkexec rm -f "$BLACKLIST_FILE"
        echo -e "${GREEN}Blacklist removido. Bluetooth cargará en próximo boot.${NC}"
        notify-send "Bluetooth" "Blacklist removido" -i bluetooth 2>/dev/null
    else
        echo "No hay blacklist activo."
    fi
}

show_help() {
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos:"
    echo "  status          Mostrar estado actual"
    echo "  status json     Mostrar estado en formato JSON"
    echo "  enable          Activar Bluetooth (remueve blacklist si existe)"
    echo "  disable         Desactivar Bluetooth temporalmente"
    echo "  disable permanent   Desactivar y agregar a blacklist"
    echo "  toggle          Alternar estado (enable/disable)"
    echo "  toggle permanent    Alternar con blacklist permanente"
    echo "  remove-blacklist    Solo remover blacklist"
    echo "  help            Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 status json     # Para integración con AGS"
    echo "  $0 toggle          # Toggle simple"
    echo "  $0 disable permanent   # Desactivar permanentemente"
}

# Main
case "${1:-status}" in
    status)
        get_status "$2"
        ;;
    enable)
        enable_bluetooth
        ;;
    disable)
        disable_bluetooth "$2"
        ;;
    toggle)
        toggle_bluetooth "$2"
        ;;
    remove-blacklist)
        remove_blacklist
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Comando desconocido: $1"
        show_help
        exit 1
        ;;
esac
