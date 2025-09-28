#!/bin/bash

# Script para limpiar procesos colgados de package managers
# Uso: ./cleanup-pacman.sh

echo "🧹 Limpieza avanzada de package managers"
echo "======================================="

# Función para limpiar procesos colgados
cleanup_package_managers() {
    echo "🔍 Buscando procesos colgados de package managers..."
    
    # Buscar PIDs específicos en lugar de usar pkill -f
    local pacman_pids=$(ps aux | grep -E "(pacman|yay|paru)" | grep -v grep | grep -v "cleanup-pacman.sh")
    
    if [ -n "$pacman_pids" ]; then
        echo "📋 Procesos encontrados:"
        echo "$pacman_pids"
        echo ""
        
        # Extraer solo los PIDs
        local pids=$(echo "$pacman_pids" | awk '{print $2}' | tr '\n' ' ')
        echo "🎯 PIDs a eliminar: $pids"
        
        # Matar procesos individualmente
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                echo "🔪 Matando proceso $pid ($process_name)..."
                
                # Intentar terminación suave primero
                sudo kill -TERM "$pid" 2>/dev/null || true
                sleep 2
                
                # Verificar si aún existe y forzar si es necesario
                if kill -0 "$pid" 2>/dev/null; then
                    echo "💀 Forzando eliminación del proceso $pid..."
                    sudo kill -9 "$pid" 2>/dev/null || true
                    sleep 1
                fi
                
                # Verificar resultado
                if kill -0 "$pid" 2>/dev/null; then
                    echo "❌ No se pudo eliminar el proceso $pid"
                else
                    echo "✅ Proceso $pid eliminado exitosamente"
                fi
            else
                echo "ℹ️  Proceso $pid ya no existe"
            fi
        done
        
        # Limpiar procesos pkill colgados específicamente
        echo ""
        echo "🔍 Buscando procesos pkill colgados..."
        local stuck_pkill=$(ps aux | grep "pkill.*\(pacman\|yay\|paru\)" | grep -v grep | awk '{print $2}' | tr '\n' ' ')
        
        if [ -n "$stuck_pkill" ]; then
            echo "🚫 Eliminando procesos pkill colgados: $stuck_pkill"
            for pid in $stuck_pkill; do
                echo "💀 Forzando eliminación de pkill $pid..."
                sudo kill -9 "$pid" 2>/dev/null || true
            done
        else
            echo "✅ No hay procesos pkill colgados"
        fi
        
    else
        echo "✅ No se encontraron procesos colgados de package managers"
    fi
}

# Función para limpiar archivos de lock
cleanup_lock_files() {
    echo ""
    echo "🔒 Verificando archivos de lock..."
    
    # Lock de pacman
    if [ -f /var/lib/pacman/db.lck ]; then
        echo "🔓 Removiendo lock de pacman..."
        sudo rm -f /var/lib/pacman/db.lck
        echo "✅ Lock de pacman removido"
    else
        echo "✅ No hay lock de pacman"
    fi
    
    # Verificar otros posibles locks
    local other_locks=$(find /tmp -name "*pacman*" -o -name "*yay*" -o -name "*paru*" 2>/dev/null | head -5)
    if [ -n "$other_locks" ]; then
        echo "ℹ️  Otros archivos temporales encontrados:"
        echo "$other_locks"
        echo "💡 Considera limpiarlos manualmente si es necesario"
    fi
}

# Función para verificar estado final
verify_cleanup() {
    echo ""
    echo "🔍 Verificación final..."
    
    local remaining=$(ps aux | grep -E "(pacman|yay|paru)" | grep -v grep | grep -v "cleanup-pacman.sh")
    
    if [ -n "$remaining" ]; then
        echo "⚠️  Aún hay algunos procesos:"
        echo "$remaining"
        echo ""
        echo "💡 Si estos procesos son legítimos (no colgados), está bien dejarlos"
    else
        echo "✅ No hay procesos de package managers ejecutándose"
    fi
    
    # Verificar que pacman funcione
    echo ""
    echo "🧪 Probando funcionalidad de pacman..."
    if timeout 5 pacman -Q pacman >/dev/null 2>&1; then
        echo "✅ Pacman funciona correctamente"
    else
        echo "⚠️  Pacman podría tener problemas - considera reiniciar si persiste"
    fi
}

# Ejecutar limpieza
main() {
    echo "🚀 Iniciando limpieza..."
    echo ""
    
    cleanup_package_managers
    cleanup_lock_files  
    verify_cleanup
    
    echo ""
    echo "🎉 Limpieza completada!"
    echo ""
    echo "💡 Comandos útiles para el futuro:"
    echo "   - Ver procesos: ps aux | grep -E '(pacman|yay|paru)' | grep -v grep"
    echo "   - Verificar locks: ls -la /var/lib/pacman/db.lck"
    echo "   - Este script: ./cleanup-pacman.sh"
}

# Verificar si se ejecuta como script principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
