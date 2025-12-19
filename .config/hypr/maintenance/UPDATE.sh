#!/bin/bash

#==============================================================================
# UPDATE.sh - System Package Update Script for ArchEclipse Rice
#==============================================================================
# This script handles system-wide package updates across multiple package
# managers without touching git repositories. Git synchronization with
# upstream should be done manually via Claude Code or git commands.
#
# Supported package managers:
#   - pacman/yay/paru (Arch Linux)
#   - flatpak
#   - snap
#   - pip/pipx (Python)
#
# Usage:
#   ./UPDATE.sh              # Interactive mode (default)
#   ./UPDATE.sh --all        # Update everything without prompts
#   ./UPDATE.sh --quick      # Quick update (AUR + flatpak only)
#   ./UPDATE.sh --help       # Show help
#==============================================================================

# Note: Not using 'set -e' because package managers may return non-zero
# exit codes for non-fatal conditions (e.g., "no updates available")

MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"
SCRIPT_NAME=$(basename "$0")

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"

# Counters for summary (using declare to ensure arithmetic works)
declare -i UPDATES_PERFORMED=0
declare -i UPDATES_SKIPPED=0
declare -i UPDATES_FAILED=0

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

log() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[✗]${RESET} $1"
}

info() {
    echo -e "${BLUE}[i]${RESET} $1"
}

header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}${BOLD}  $1${RESET}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

subheader() {
    echo -e "\n${MAGENTA}▸ $1${RESET}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Handle errors - show message and ask user if they want to continue
handle_error() {
    local exit_code=$1
    local component=$2
    local message=$3

    if [ $exit_code -ne 0 ]; then
        error "$component falló (código: $exit_code)"
        [ -n "$message" ] && echo -e "  ${DIM}$message${RESET}"
        UPDATES_FAILED+=1

        echo ""
        echo -e "${YELLOW}¿Desea continuar con las siguientes actualizaciones?${RESET}"
        read -p "[S/n]: " choice
        case "$choice" in
            [Nn]*)
                warn "Actualización cancelada por el usuario"
                show_summary
                exit 1
                ;;
            *)
                info "Continuando..."
                return 0
                ;;
        esac
    fi
    return 0
}

show_help() {
    cat << EOF
${CYAN}${BOLD}ArchEclipse System Update Script${RESET}

${BOLD}Usage:${RESET}
    $SCRIPT_NAME [OPTIONS]

${BOLD}Options:${RESET}
    ${GREEN}--all${RESET}       Update all package managers without prompts
    ${GREEN}--quick${RESET}     Quick update: AUR packages + flatpak only
    ${GREEN}--aur${RESET}       Update AUR packages only (yay/paru)
    ${GREEN}--flatpak${RESET}   Update flatpak packages only
    ${GREEN}--snap${RESET}      Update snap packages only
    ${GREEN}--pip${RESET}       Update pip/pipx packages only
    ${GREEN}--rice${RESET}      Run rice maintenance scripts only (wallpapers, wal, plugins)
    ${GREEN}--clean${RESET}     Clean system caches only
    ${GREEN}--services${RESET}  Verify Hyprland services only
    ${GREEN}--help, -h${RESET}  Show this help message

${BOLD}Examples:${RESET}
    $SCRIPT_NAME                 # Interactive mode
    $SCRIPT_NAME --all           # Full system update
    $SCRIPT_NAME --quick         # Fast daily update
    $SCRIPT_NAME --aur --flatpak # Specific managers only

${BOLD}Note:${RESET}
    This script does NOT handle git repository updates.
    For syncing with upstream, use Claude Code or manual git commands.

EOF
    exit 0
}

#------------------------------------------------------------------------------
# Package Manager Detection
#------------------------------------------------------------------------------

detect_aur_helper() {
    local helpers=("yay" "paru")
    for helper in "${helpers[@]}"; do
        if command_exists "$helper"; then
            echo "$helper"
            return 0
        fi
    done
    return 1
}

#------------------------------------------------------------------------------
# Cleanup Functions
#------------------------------------------------------------------------------

cleanup_package_managers() {
    subheader "Limpiando procesos de package managers colgados..."

    local pacman_pids=$(ps aux | grep -E "(pacman|yay|paru)" | grep -v grep | awk '{print $2}' | tr '\n' ' ')

    if [ -n "$pacman_pids" ]; then
        info "Procesos encontrados: $pacman_pids"

        for pid in $pacman_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                warn "Terminando proceso $pid..."
                sudo kill -TERM "$pid" 2>/dev/null || true
                sleep 1

                if kill -0 "$pid" 2>/dev/null; then
                    error "Forzando terminación de proceso $pid..."
                    sudo kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
    else
        log "No hay procesos colgados"
    fi

    # Remove pacman lock file if it exists
    if [ -f /var/lib/pacman/db.lck ]; then
        warn "Eliminando archivo de bloqueo de pacman..."
        sudo rm -f /var/lib/pacman/db.lck
        log "Archivo de bloqueo eliminado"
    fi
}

clean_system_cache() {
    subheader "Limpiando cachés del sistema..."

    local cleaned=false

    # Pacman cache - keep only last 2 versions
    if command_exists paccache; then
        info "Limpiando caché de pacman (manteniendo últimas 2 versiones)..."
        sudo paccache -rk2 2>/dev/null && cleaned=true
    fi

    # Yay/Paru cache
    local aur_helper=$(detect_aur_helper)
    if [ -n "$aur_helper" ]; then
        local cache_dir="$HOME/.cache/$aur_helper"
        if [ -d "$cache_dir" ]; then
            local cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            info "Limpiando caché de $aur_helper ($cache_size)..."
            rm -rf "$cache_dir"/* 2>/dev/null && cleaned=true
        fi
    fi

    # Flatpak unused runtimes
    if command_exists flatpak; then
        info "Eliminando runtimes de flatpak no utilizados..."
        flatpak uninstall --unused -y 2>/dev/null && cleaned=true || true
    fi

    # Snap cache
    if command_exists snap; then
        info "Limpiando versiones antiguas de snaps..."
        snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
            sudo snap remove "$snapname" --revision="$revision" 2>/dev/null && cleaned=true || true
        done
    fi

    # Journal logs - keep only last 3 days
    if command_exists journalctl; then
        info "Limpiando logs del journal (>3 días)..."
        sudo journalctl --vacuum-time=3d 2>/dev/null && cleaned=true || true
    fi

    # Thumbnail cache
    local thumb_cache="$HOME/.cache/thumbnails"
    if [ -d "$thumb_cache" ]; then
        local thumb_size=$(du -sh "$thumb_cache" 2>/dev/null | cut -f1)
        info "Limpiando caché de miniaturas ($thumb_size)..."
        rm -rf "$thumb_cache"/* 2>/dev/null && cleaned=true
    fi

    if [ "$cleaned" = true ]; then
        log "Limpieza de caché completada"
        UPDATES_PERFORMED+=1
    else
        warn "No se encontraron cachés para limpiar"
    fi
}

#------------------------------------------------------------------------------
# Update Functions
#------------------------------------------------------------------------------

update_aur_packages() {
    header "Actualizando Paquetes AUR"

    local aur_helper=$(detect_aur_helper)

    if [ -z "$aur_helper" ]; then
        warn "No se encontró yay ni paru. Instalando yay..."
        source "$MAINTENANCE_DIR/ESSENTIALS.sh"
        install_yay
        aur_helper="yay"
    fi

    info "Usando $aur_helper como helper de AUR"

    # Check for updates first
    subheader "Verificando actualizaciones disponibles..."
    local updates=$($aur_helper -Qu 2>/dev/null | wc -l)

    if [ "$updates" -gt 0 ]; then
        info "Se encontraron $updates paquetes para actualizar"

        local exit_code=0
        if [ "$AUTO_MODE" = true ]; then
            $aur_helper -Syu --noconfirm || exit_code=$?
        else
            $aur_helper -Syu || exit_code=$?
        fi

        if [ $exit_code -eq 0 ]; then
            log "Paquetes AUR actualizados"
            UPDATES_PERFORMED+=1
        else
            handle_error $exit_code "AUR ($aur_helper)" "Ver output arriba"
        fi
    else
        log "Todos los paquetes AUR están actualizados"
        UPDATES_SKIPPED+=1
    fi

    # Remove deprecated agsv1 if present
    if pacman -Q agsv1 &>/dev/null; then
        warn "Eliminando paquete obsoleto agsv1..."
        $aur_helper -Rns agsv1 --noconfirm 2>/dev/null || true
    fi
}

update_flatpak() {
    header "Actualizando Flatpak"

    if ! command_exists flatpak; then
        warn "Flatpak no está instalado"
        UPDATES_SKIPPED+=1
        return 0
    fi

    # Check for updates
    subheader "Verificando actualizaciones de Flatpak..."
    local updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)

    if [ "$updates" -gt 0 ]; then
        info "Se encontraron $updates actualizaciones de Flatpak"

        local exit_code=0
        if [ "$AUTO_MODE" = true ]; then
            flatpak update -y || exit_code=$?
        else
            flatpak update || exit_code=$?
        fi

        if [ $exit_code -eq 0 ]; then
            log "Flatpak actualizado"
            UPDATES_PERFORMED+=1
        else
            handle_error $exit_code "Flatpak" "Ver output arriba"
        fi
    else
        log "Todos los paquetes Flatpak están actualizados"
        UPDATES_SKIPPED+=1
    fi
}

update_snap() {
    header "Actualizando Snap"

    if ! command_exists snap; then
        warn "Snap no está instalado"
        UPDATES_SKIPPED+=1
        return 0
    fi

    subheader "Actualizando paquetes Snap..."

    local exit_code=0
    sudo snap refresh || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log "Snap actualizado"
        UPDATES_PERFORMED+=1
    else
        # snap returns non-zero when no updates, check manually
        if snap changes 2>/dev/null | tail -1 | grep -q "Done"; then
            log "Todos los snaps están actualizados"
            UPDATES_SKIPPED+=1
        else
            handle_error $exit_code "Snap" "Ver output arriba"
        fi
    fi
}

update_pip_packages() {
    header "Actualizando Paquetes Python"

    # pipx (recommended for user packages)
    if command_exists pipx; then
        subheader "Actualizando paquetes pipx..."

        local exit_code=0
        pipx upgrade-all || exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log "Paquetes pipx actualizados"
            UPDATES_PERFORMED+=1
        else
            # pipx returns 1 when nothing to upgrade
            log "No hay paquetes pipx para actualizar"
            UPDATES_SKIPPED+=1
        fi
    else
        info "pipx no está instalado (opcional)"
    fi

    # pip user packages (with caution)
    if command_exists pip; then
        subheader "Verificando paquetes pip del usuario..."

        # List outdated user packages
        local outdated=$(pip list --user --outdated --format=freeze 2>/dev/null | wc -l)

        if [ "$outdated" -gt 0 ]; then
            info "Se encontraron $outdated paquetes pip desactualizados"

            if [ "$AUTO_MODE" = true ]; then
                local exit_code=0
                pip list --user --outdated --format=freeze 2>/dev/null | cut -d= -f1 | xargs -n1 pip install --user --upgrade || exit_code=$?

                if [ $exit_code -eq 0 ]; then
                    log "Paquetes pip actualizados"
                    UPDATES_PERFORMED+=1
                else
                    handle_error $exit_code "pip" "Ver output arriba"
                fi
            else
                warn "Para actualizar pip manualmente, ejecute:"
                echo "  pip list --user --outdated"
                echo "  pip install --user --upgrade <package>"
            fi
        else
            log "Todos los paquetes pip están actualizados"
        fi
    else
        info "pip no está instalado (opcional)"
    fi
}

#------------------------------------------------------------------------------
# Rice Maintenance Functions
#------------------------------------------------------------------------------

run_rice_maintenance() {
    header "Mantenimiento de la Rice"

    # Wallpapers
    if [ -f "$MAINTENANCE_DIR/WALLPAPERS.sh" ]; then
        subheader "Verificando wallpapers..."
        "$MAINTENANCE_DIR/WALLPAPERS.sh"
        UPDATES_PERFORMED+=1
    fi

    # Pywal theme
    if [ -f "$MAINTENANCE_DIR/WAL.sh" ]; then
        subheader "Actualizando tema pywal..."
        "$MAINTENANCE_DIR/WAL.sh"
        UPDATES_PERFORMED+=1
    fi

    # Hyprland plugins
    if [ -f "$MAINTENANCE_DIR/PLUGINS.sh" ]; then
        subheader "Actualizando plugins de Hyprland..."
        "$MAINTENANCE_DIR/PLUGINS.sh"
        UPDATES_PERFORMED+=1
    fi

    # Tweaks
    if [ -f "$MAINTENANCE_DIR/TWEAKS.sh" ]; then
        subheader "Aplicando tweaks..."
        "$MAINTENANCE_DIR/TWEAKS.sh"
        UPDATES_PERFORMED+=1
    fi

    log "Mantenimiento de rice completado"
}

#------------------------------------------------------------------------------
# Service Verification
#------------------------------------------------------------------------------

verify_hyprland_services() {
    header "Verificando Servicios de Hyprland"

    local services=(
        "hyprland-monitor-hotplug.service"
        "hyprland-lid-handler.service"
    )

    for service in "${services[@]}"; do
        subheader "Verificando $service..."

        if systemctl --user is-active --quiet "$service" 2>/dev/null; then
            log "$service está activo"
        else
            warn "$service no está activo"

            if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
                info "Intentando reiniciar $service..."
                systemctl --user restart "$service" 2>/dev/null && \
                    log "Servicio reiniciado" || \
                    error "No se pudo reiniciar el servicio"
            else
                info "El servicio no está habilitado. Para habilitarlo:"
                echo "  systemctl --user enable --now $service"
            fi
        fi
    done

    # Check AGS
    subheader "Verificando AGS..."
    if pgrep -x "gjs" > /dev/null || pgrep -f "ags" > /dev/null; then
        log "AGS está ejecutándose"
    else
        warn "AGS no está ejecutándose"
        info "Para iniciar AGS: ags run --gtk 3"
    fi

    # Check clipboard monitor
    subheader "Verificando monitor de clipboard..."
    if pgrep -f "wl-paste.*clipboard" > /dev/null; then
        log "Monitor de clipboard está activo"
    else
        warn "Monitor de clipboard no está activo"
        info "Para iniciarlo: ~/.config/hypr/scripts/start-clipboard-monitor.sh"
    fi
}

#------------------------------------------------------------------------------
# Interactive Mode
#------------------------------------------------------------------------------

interactive_mode() {
    source "$MAINTENANCE_DIR/ESSENTIALS.sh"

    header "Modo Interactivo"

    echo -e "${BOLD}Seleccione las actualizaciones a realizar:${RESET}\n"

    # AUR packages
    if continue_prompt "¿Actualizar paquetes AUR (yay/paru)?"; then
        cleanup_package_managers
        update_aur_packages
    else
        UPDATES_SKIPPED+=1
    fi

    # Flatpak
    if command_exists flatpak; then
        if continue_prompt "¿Actualizar paquetes Flatpak?"; then
            update_flatpak
        else
            UPDATES_SKIPPED+=1
        fi
    fi

    # Snap
    if command_exists snap; then
        if continue_prompt "¿Actualizar paquetes Snap?"; then
            update_snap
        else
            UPDATES_SKIPPED+=1
        fi
    fi

    # Python packages
    if command_exists pipx || command_exists pip; then
        if continue_prompt "¿Actualizar paquetes Python (pipx/pip)?"; then
            update_pip_packages
        else
            UPDATES_SKIPPED+=1
        fi
    fi

    # Rice maintenance
    if continue_prompt "¿Ejecutar mantenimiento de la rice (wallpapers, wal, plugins)?"; then
        run_rice_maintenance
    else
        UPDATES_SKIPPED+=1
    fi

    # Cache cleanup
    if continue_prompt "¿Limpiar cachés del sistema?"; then
        clean_system_cache
    else
        UPDATES_SKIPPED+=1
    fi

    # Service verification
    if continue_prompt "¿Verificar servicios de Hyprland?"; then
        verify_hyprland_services
    else
        UPDATES_SKIPPED+=1
    fi
}

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

show_summary() {
    header "Resumen de Actualización"

    echo -e "  ${GREEN}Actualizaciones realizadas:${RESET} $UPDATES_PERFORMED"
    echo -e "  ${YELLOW}Actualizaciones omitidas:${RESET}  $UPDATES_SKIPPED"
    echo -e "  ${RED}Actualizaciones fallidas:${RESET}  $UPDATES_FAILED"
    echo ""

    if [ $UPDATES_FAILED -eq 0 ]; then
        log "Sistema actualizado correctamente"
    else
        warn "Algunas actualizaciones fallaron. Revise los mensajes anteriores."
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Parse arguments
    AUTO_MODE=false
    QUICK_MODE=false
    SPECIFIC_MODE=""

    for arg in "$@"; do
        case $arg in
            --all)
                AUTO_MODE=true
                ;;
            --quick)
                QUICK_MODE=true
                ;;
            --aur)
                SPECIFIC_MODE="aur"
                ;;
            --flatpak)
                SPECIFIC_MODE="flatpak"
                ;;
            --snap)
                SPECIFIC_MODE="snap"
                ;;
            --pip)
                SPECIFIC_MODE="pip"
                ;;
            --rice)
                SPECIFIC_MODE="rice"
                ;;
            --clean)
                SPECIFIC_MODE="clean"
                ;;
            --services)
                SPECIFIC_MODE="services"
                ;;
            --help|-h)
                show_help
                ;;
            *)
                error "Argumento desconocido: $arg"
                show_help
                ;;
        esac
    done

    # Banner
    if command_exists figlet; then
        figlet "Update Rice"
    else
        echo -e "${CYAN}${BOLD}"
        echo "╔═══════════════════════════════════════════╗"
        echo "║         ArchEclipse System Update         ║"
        echo "╚═══════════════════════════════════════════╝"
        echo -e "${RESET}"
    fi

    info "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Source essentials for utility functions
    if [ -f "$MAINTENANCE_DIR/ESSENTIALS.sh" ]; then
        source "$MAINTENANCE_DIR/ESSENTIALS.sh"
    fi

    # Execute based on mode
    if [ -n "$SPECIFIC_MODE" ]; then
        # Specific mode
        case $SPECIFIC_MODE in
            aur)
                cleanup_package_managers
                update_aur_packages
                ;;
            flatpak)
                update_flatpak
                ;;
            snap)
                update_snap
                ;;
            pip)
                update_pip_packages
                ;;
            rice)
                run_rice_maintenance
                ;;
            clean)
                clean_system_cache
                ;;
            services)
                verify_hyprland_services
                ;;
        esac
    elif [ "$QUICK_MODE" = true ]; then
        # Quick mode: AUR + flatpak
        cleanup_package_managers
        update_aur_packages
        update_flatpak
    elif [ "$AUTO_MODE" = true ]; then
        # Full auto mode
        cleanup_package_managers
        update_aur_packages
        update_flatpak
        update_snap
        update_pip_packages
        run_rice_maintenance
        clean_system_cache
        verify_hyprland_services
    else
        # Interactive mode (default)
        interactive_mode
    fi

    # Show summary
    show_summary
}

# Run main function
main "$@"
