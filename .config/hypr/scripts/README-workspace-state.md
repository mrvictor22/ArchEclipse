# Sistema de Preservación de Workspaces para KVM

## 🎯 Propósito

Este sistema resuelve el problema de que las aplicaciones se desorganizan cuando cambias entre laptops usando un switch KVM. Ahora tus aplicaciones permanecerán en los workspaces donde las dejaste.

## 🔧 Componentes

### 1. `workspace-state-manager.sh`
Script principal que gestiona el guardado y restauración del estado de los workspaces.

**Comandos disponibles:**
```bash
# Guardar el estado actual de todos los workspaces
~/.config/hypr/scripts/workspace-state-manager.sh save

# Restaurar las aplicaciones a sus workspaces guardados
~/.config/hypr/scripts/workspace-state-manager.sh restore

# Ver el estado guardado
~/.config/hypr/scripts/workspace-state-manager.sh show

# Ver el estado actual en vivo
~/.config/hypr/scripts/workspace-state-manager.sh current

# Limpiar el estado guardado
~/.config/hypr/scripts/workspace-state-manager.sh clear

# Auto-restaurar (solo si el estado es reciente, menos de 10 minutos)
~/.config/hypr/scripts/workspace-state-manager.sh auto-restore
```

### 2. `monitor-hotplug.sh` (Modificado)
El script de detección de monitores ahora incluye integración automática con el sistema de workspaces.

**Nuevos comandos:**
```bash
# Guardar workspace manualmente
~/.config/hypr/scripts/monitor-hotplug.sh save-workspace

# Restaurar workspace manualmente
~/.config/hypr/scripts/monitor-hotplug.sh restore-workspace
```

## 🚀 Funcionamiento Automático

El sistema funciona automáticamente cuando:

1. **Detecta desconexión de monitor (cambio a otra laptop con KVM)**
   - Guarda el estado actual de todas las ventanas y sus workspaces
   - Guarda: clase de ventana, título, workspace, monitor

2. **Detecta reconexión de monitor (vuelves a tu laptop)**
   - Espera a que la configuración de monitores se estabilice
   - Restaura automáticamente las ventanas a sus workspaces originales
   - Solo restaura si el estado guardado es reciente (< 10 minutos)

## 📁 Archivos de Estado

Los estados se guardan en:
- **Estado actual:** `~/.cache/hypr/workspace-states/current-state.json`
- **Backups:** `~/.cache/hypr/workspace-states/backup-*.json` (últimos 5)
- **Logs:** `/tmp/hyprland-workspace-state.log`

## 🧪 Cómo Probar

### Test 1: Guardado y restauración manual
```bash
# 1. Organiza tus ventanas como las quieres
# 2. Guarda el estado
~/.config/hypr/scripts/workspace-state-manager.sh save

# 3. Mueve algunas ventanas a otros workspaces manualmente
# 4. Restaura el estado
~/.config/hypr/scripts/workspace-state-manager.sh restore

# Las ventanas deberían volver a sus posiciones originales
```

### Test 2: Con KVM
```bash
# 1. Organiza tus ventanas
# 2. Cambia a otra laptop con el KVM
# 3. El sistema guarda automáticamente el estado
# 4. Vuelve a tu laptop con Arch
# 5. El sistema restaura automáticamente las ventanas
```

### Test 3: Ver el estado
```bash
# Ver qué está guardado
~/.config/hypr/scripts/workspace-state-manager.sh show

# Comparar con el estado actual
~/.config/hypr/scripts/workspace-state-manager.sh current
```

## 🔍 Debugging

Si algo no funciona:

1. **Ver logs del workspace manager:**
```bash
tail -f /tmp/hyprland-workspace-state.log
```

2. **Ver logs del monitor hotplug:**
```bash
tail -f /tmp/hyprland-monitor-hotplug.log
```

3. **Ver el estado guardado:**
```bash
cat ~/.cache/hypr/workspace-states/current-state.json | jq
```

4. **Verificar que el script esté corriendo:**
```bash
pgrep -f monitor-hotplug
```

## ⚙️ Configuración

### Tiempo de validez del estado guardado
Por defecto, el estado solo se restaura si tiene menos de 10 minutos. Para cambiar esto, edita en `workspace-state-manager.sh`:

```bash
# Línea ~175, cambia 600 (10 minutos) al valor deseado en segundos
if [ $state_age -lt 600 ]; then
```

### Desactivar restauración automática
Si prefieres control manual, comenta estas líneas en `monitor-hotplug.sh`:

```bash
# Línea ~126
# save_workspace_state

# Líneas ~150-151
# sleep 2
# restore_workspace_state
```

## 🐛 Problemas Conocidos

1. **Aplicaciones que cambian de clase/título**
   - El sistema identifica ventanas por su clase y título inicial
   - Algunas aplicaciones cambian estos valores dinámicamente
   - Solución: El script usa `initialClass` como backup

2. **Ventanas que se cierran durante el cambio**
   - Si cierras una ventana antes de volver al monitor, obviamente no se puede restaurar
   - El sistema registra esto en el log

3. **Aplicaciones con múltiples ventanas**
   - Si una app tiene varias ventanas con la misma clase, se restauran en orden
   - Puede no ser perfecto, pero funciona en la mayoría de casos

## 📝 Logs de Ejemplo

```log
[2025-11-03 08:45:23] === Saving workspace state ===
[2025-11-03 08:45:23] State captured: 15 windows
[2025-11-03 08:45:23] State saved successfully
[2025-11-03 08:45:35] === Restoring workspace state ===
[2025-11-03 08:45:37] Attempting to restore 15 windows...
[2025-11-03 08:45:37] Moving window: kitty (ws 2 -> 1)
[2025-11-03 08:45:37] Moving window: firefox (ws 1 -> 3)
[2025-11-03 08:45:38] Window already in correct workspace: spotify (ws 4)
[2025-11-03 08:45:38] Restoration complete.
```

## 🎉 Beneficios

- ✅ Recuperas tu distribución de workspaces al volver del KVM
- ✅ Funciona automáticamente, sin intervención manual
- ✅ Guarda backups por si algo sale mal
- ✅ Logs detallados para debugging
- ✅ Puedes usar comandos manuales cuando lo necesites
- ✅ Solo restaura estados recientes (evita restaurar estados viejos por error)

## 🚨 Notas Importantes

1. El sistema requiere que `monitor-hotplug.sh` esté corriendo en modo `monitor`
2. Verifica que esté en tu autostart de Hyprland
3. Los permisos de ejecución deben estar correctos (chmod +x)
4. Requiere `jq` instalado para parsear JSON
