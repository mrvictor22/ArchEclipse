#!/bin/bash
# setup-razer.sh - Instalador interactivo para Razer Cobra en Arch Linux
# Instala OpenRazer + Polychromatic
# 2026-02-07

RAZER_VID="1532"
RAZER_PID="00a3"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
info() { echo -e "  ${BLUE}→${NC} $1"; }

separator() { echo -e "${DIM}  $(printf '%.0s─' {1..46})${NC}"; }

header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}  ║         🐍 Razer Cobra Setup Tool           ║${NC}"
    echo -e "${CYAN}${BOLD}  ╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

pause() {
    echo ""
    read -rp "  Presiona Enter para continuar..." _
}

confirm() {
    echo ""
    read -rp "  $1 [s/N]: " reply
    [[ "$reply" =~ ^[sS]$ ]]
}

pkg_installed() { pacman -Q "$1" &>/dev/null; }

pkg_version() { pacman -Q "$1" 2>/dev/null | awk '{print $2}'; }

# ─── Detección de hardware ───

detect_hw() {
    echo -e "\n${BOLD}  Hardware${NC}"
    separator

    local usb
    usb=$(lsusb 2>/dev/null | grep -i "${RAZER_VID}:${RAZER_PID}")
    if [ -n "$usb" ]; then
        ok "Mouse detectado: ${DIM}$usb${NC}"
    else
        fail "Razer Cobra (${RAZER_VID}:${RAZER_PID}) no conectado"
    fi

    local kernel
    kernel=$(uname -r)
    ok "Kernel: ${DIM}${kernel}${NC}"

    if command -v mokutil &>/dev/null; then
        if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
            fail "Secure Boot activo — los módulos DKMS no cargarán"
        else
            ok "Secure Boot desactivado"
        fi
    fi
}

# ─── Estado de paquetes ───

show_status() {
    header
    echo -e "${BOLD}  Estado de la instalación${NC}"
    separator

    local pkgs=(linux-headers dkms openrazer-driver-dkms openrazer-daemon python-openrazer)
    local aur_pkgs=(polychromatic)

    for pkg in "${pkgs[@]}"; do
        if pkg_installed "$pkg"; then
            ok "$pkg ${DIM}($(pkg_version "$pkg"))${NC}"
        else
            fail "$pkg no instalado"
        fi
    done
    for pkg in "${aur_pkgs[@]}"; do
        if pkg_installed "$pkg"; then
            ok "$pkg ${DIM}($(pkg_version "$pkg"))${NC}"
        else
            fail "$pkg no instalado"
        fi
    done

    detect_hw

    echo -e "\n${BOLD}  Servicios${NC}"
    separator

    if systemctl --user is-active openrazer-daemon.service &>/dev/null; then
        ok "openrazer-daemon activo"
    else
        fail "openrazer-daemon no activo"
    fi

    if lsmod | grep -q razer; then
        ok "Módulos kernel razer cargados"
    else
        fail "Módulos kernel razer no cargados"
    fi

    if groups "$USER" | grep -qw openrazer; then
        ok "Usuario en grupo openrazer"
    else
        fail "Usuario NO en grupo openrazer"
    fi

    local dkms_st
    dkms_st=$(dkms status 2>/dev/null | grep openrazer)
    if [ -n "$dkms_st" ]; then
        ok "DKMS: ${DIM}${dkms_st}${NC}"
    else
        fail "Módulo DKMS openrazer no registrado"
    fi

    pause
}

# ─── Instalación ───

do_install() {
    header
    echo -e "${BOLD}  Instalación de OpenRazer + Polychromatic${NC}"
    separator
    detect_hw
    echo ""

    if ! confirm "¿Iniciar instalación?"; then
        info "Cancelado."
        return
    fi

    local needs_reboot=false
    local headers_pkg="linux-headers"
    uname -r | grep -q "lts" && headers_pkg="linux-lts-headers"

    # 1) Kernel headers + DKMS
    echo -e "\n${BOLD}  [1/5] Kernel headers + DKMS${NC}"
    separator
    local repo_pkgs=()
    for pkg in "$headers_pkg" dkms; do
        if pkg_installed "$pkg"; then
            ok "$pkg ya instalado"
        else
            repo_pkgs+=("$pkg")
        fi
    done
    if [ ${#repo_pkgs[@]} -gt 0 ]; then
        info "Instalando ${repo_pkgs[*]}..."
        sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}" && \
            ok "Instalados" || { fail "Error en pacman"; return; }
    fi

    # 2) OpenRazer
    echo -e "\n${BOLD}  [2/5] OpenRazer${NC}"
    separator
    repo_pkgs=()
    for pkg in openrazer-driver-dkms openrazer-daemon python-openrazer; do
        if pkg_installed "$pkg"; then
            ok "$pkg ya instalado"
        else
            repo_pkgs+=("$pkg")
        fi
    done
    if [ ${#repo_pkgs[@]} -gt 0 ]; then
        info "Instalando ${repo_pkgs[*]}..."
        sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}" && \
            ok "OpenRazer instalado" || { fail "Error en pacman"; return; }
        needs_reboot=true
    fi

    # 3) Polychromatic
    echo -e "\n${BOLD}  [3/5] Polychromatic (AUR)${NC}"
    separator
    if pkg_installed polychromatic; then
        ok "polychromatic ya instalado"
    else
        if ! command -v yay &>/dev/null; then
            fail "yay no encontrado — instálalo primero"
            return
        fi
        info "Instalando polychromatic desde AUR..."
        yay -S --needed polychromatic && \
            ok "Polychromatic instalado" || { fail "Error en yay"; return; }
    fi

    # 4) Grupo
    echo -e "\n${BOLD}  [4/5] Grupo de usuario${NC}"
    separator
    if groups "$USER" | grep -qw openrazer; then
        ok "$USER ya en grupo openrazer"
    else
        info "Agregando $USER al grupo openrazer..."
        sudo gpasswd -a "$USER" openrazer && \
            ok "Agregado al grupo" || fail "No se pudo agregar"
        needs_reboot=true
    fi

    # 5) Daemon
    echo -e "\n${BOLD}  [5/5] Servicio OpenRazer${NC}"
    separator
    systemctl --user enable openrazer-daemon.service 2>/dev/null
    ok "openrazer-daemon habilitado"

    if systemctl --user is-active openrazer-daemon.service &>/dev/null; then
        ok "Daemon ya corriendo"
    else
        systemctl --user start openrazer-daemon.service 2>/dev/null && \
            ok "Daemon iniciado" || warn "No se pudo iniciar (reinicia primero)"
    fi

    # Resultado
    echo ""
    separator
    echo -e "\n${GREEN}${BOLD}  Instalación completada.${NC}"

    if [ "$needs_reboot" = true ]; then
        warn "Se requiere reiniciar para cargar los módulos del kernel."
        if confirm "¿Reiniciar ahora?"; then
            sudo reboot
        else
            info "Reinicia cuando puedas."
        fi
    else
        ok "Todo listo — abre Polychromatic desde el menú o con: polychromatic-controller"
    fi

    pause
}

# ─── Desinstalación ───

do_uninstall() {
    header
    echo -e "${BOLD}  Desinstalar OpenRazer + Polychromatic${NC}"
    separator
    echo ""
    info "Se eliminarán:"
    echo "      polychromatic"
    echo "      python-openrazer"
    echo "      openrazer-daemon"
    echo "      openrazer-driver-dkms"

    if ! confirm "¿Continuar?"; then
        info "Cancelado."
        return
    fi

    info "Deteniendo daemon..."
    systemctl --user stop openrazer-daemon.service 2>/dev/null
    systemctl --user disable openrazer-daemon.service 2>/dev/null

    info "Desinstalando paquetes..."
    sudo pacman -Rns --noconfirm polychromatic python-openrazer openrazer-daemon openrazer-driver-dkms 2>/dev/null
    ok "Paquetes eliminados"

    if [ -d "$HOME/.config/polychromatic" ] && confirm "¿Eliminar config de Polychromatic?"; then
        rm -rf "$HOME/.config/polychromatic"
        ok "~/.config/polychromatic eliminado"
    fi

    if [ -d "$HOME/.config/openrazer" ] && confirm "¿Eliminar config de OpenRazer?"; then
        rm -rf "$HOME/.config/openrazer"
        ok "~/.config/openrazer eliminado"
    fi

    echo ""
    ok "Desinstalación completada. Reinicia para descargar módulos."
    pause
}

# ─── Menú principal ───

main_menu() {
    while true; do
        header

        # Quick status line
        local st_or="${RED}no${NC}" st_poly="${RED}no${NC}" st_mouse="${RED}no${NC}"
        pkg_installed openrazer-daemon && st_or="${GREEN}sí${NC}"
        pkg_installed polychromatic && st_poly="${GREEN}sí${NC}"
        lsusb 2>/dev/null | grep -qi "${RAZER_VID}:${RAZER_PID}" && st_mouse="${GREEN}sí${NC}"

        echo -e "  OpenRazer: ${st_or}  │  Polychromatic: ${st_poly}  │  Mouse: ${st_mouse}"
        echo ""
        separator
        echo ""
        echo -e "  ${BOLD}1${NC})  Instalar todo"
        echo -e "  ${BOLD}2${NC})  Ver estado detallado"
        echo -e "  ${BOLD}3${NC})  Desinstalar"
        echo -e "  ${BOLD}4${NC})  Abrir Polychromatic"
        echo -e "  ${BOLD}0${NC})  Salir"
        echo ""
        read -rp "  Opción: " choice

        case "$choice" in
            1) do_install ;;
            2) show_status ;;
            3) do_uninstall ;;
            4)
                if command -v polychromatic-controller &>/dev/null; then
                    polychromatic-controller &>/dev/null &
                    disown
                    ok "Polychromatic abierto"
                    sleep 1
                else
                    fail "Polychromatic no instalado — usa opción 1"
                    pause
                fi
                ;;
            0|q) echo ""; info "Hasta luego."; echo ""; exit 0 ;;
            *) warn "Opción no válida" ;;
        esac
    done
}

# ─── Entry point ───

if [ "$EUID" -eq 0 ]; then
    fail "No ejecutes como root. El script pide sudo cuando lo necesita."
    exit 1
fi

main_menu
