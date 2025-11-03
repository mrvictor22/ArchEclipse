# ✅ Sistema de Preservación de Workspaces - INSTALADO

## 🎯 Problema Resuelto

Cuando usabas tu switch KVM y pasabas de una laptop a otra, las aplicaciones se desorganizaban y cambiaban de workspace. Ahora el sistema guarda y restaura automáticamente la posición de todas tus aplicaciones.

## 🚀 Estado Actual

✅ **Sistema instalado y funcionando**
- Script principal: `~/.config/hypr/scripts/workspace-state-manager.sh`
- Integración automática: `~/.config/hypr/scripts/monitor-hotplug.sh`
- Servicio activo: `hyprland-monitor-hotplug.service` (running)
- Estado actual guardado: 6 ventanas detectadas

## 🔄 Cómo Funciona

### Automático (Ya configurado)
1. **Cuando cambias a otra laptop con KVM:**
   - El sistema detecta que el monitor se desconecta
   - Guarda automáticamente el estado de todas las ventanas y sus workspaces

2. **Cuando vuelves a tu laptop:**
   - El sistema detecta que el monitor se reconecta
   - Espera a que todo se estabilice (configuración de monitores, AGS, etc.)
   - Restaura automáticamente todas las ventanas a sus workspaces originales

### Manual (Opcional)

Puedes usar comandos directos si lo prefieres:

```bash
# Guardar estado antes de cambiar KVM
~/.config/hypr/scripts/workspace-state-manager.sh save

# Restaurar estado después de volver
~/.config/hypr/scripts/workspace-state-manager.sh restore

# Ver qué está guardado
~/.config/hypr/scripts/workspace-state-manager.sh show

# Ver estado actual
~/.config/hypr/scripts/workspace-state-manager.sh current
```

## ⌨️ Keybinds Opcionales

Si quieres controles de teclado, agrega a `~/.config/hypr/configs/keybinds.conf`:

```conf
# Guardar estado (Super + Shift + F9)
bind = $mainMod SHIFT, F9, exec, ~/.config/hypr/scripts/workspace-state-manager.sh save && notify-send "Workspace State" "Estado guardado"

# Restaurar estado (Super + Shift + F10)
bind = $mainMod SHIFT, F10, exec, ~/.config/hypr/scripts/workspace-state-manager.sh restore && notify-send "Workspace State" "Estado restaurado"
```

Ver archivo: `~/.config/hypr/scripts/KEYBINDS-workspace-state.conf`

## 📊 Estado Actual del Sistema

Tu configuración actual:
- **Firefox** en workspace 1 y 2
- **Windsurf** en workspace 3
- **Kitty/btop** en workspace 5
- **Teams** en workspace 9 y 10

Estos estados se guardarán y restaurarán automáticamente.

## 🧪 Cómo Probar

### Test Rápido (Sin KVM)
1. Guarda el estado actual:
   ```bash
   ~/.config/hypr/scripts/workspace-state-manager.sh save
   ```

2. Mueve algunas ventanas a otros workspaces manualmente

3. Restaura el estado:
   ```bash
   ~/.config/hypr/scripts/workspace-state-manager.sh restore
   ```

4. ✅ Las ventanas deberían volver a sus posiciones originales

### Test Real (Con KVM)
1. Organiza tus ventanas como las quieres
2. Cambia a la otra laptop con el KVM
3. Trabaja en la otra laptop
4. Vuelve a tu laptop Arch con el KVM
5. ✅ Espera 3-5 segundos y tus ventanas se restaurarán automáticamente

## 📁 Archivos Importantes

- **Script principal:** `~/.config/hypr/scripts/workspace-state-manager.sh`
- **Monitor hotplug:** `~/.config/hypr/scripts/monitor-hotplug.sh` (modificado)
- **Estado guardado:** `~/.cache/hypr/workspace-states/current-state.json`
- **Backups:** `~/.cache/hypr/workspace-states/backup-*.json` (últimos 5)
- **Logs workspace:** `/tmp/hyprland-workspace-state.log`
- **Logs monitor:** `/tmp/hyprland-monitor-hotplug.log`

## 🔍 Debugging

Si algo no funciona como esperas:

```bash
# Ver logs del workspace manager
tail -f /tmp/hyprland-workspace-state.log

# Ver logs del monitor hotplug
tail -f /tmp/hyprland-monitor-hotplug.log

# Ver el JSON guardado
cat ~/.cache/hypr/workspace-states/current-state.json | jq

# Verificar servicio
systemctl --user status hyprland-monitor-hotplug.service
```

## ⚙️ Configuraciones

### Tiempo de validez del estado
Por defecto, el estado solo se restaura si tiene menos de **10 minutos** de antigüedad.
Esto evita restaurar estados muy viejos por error.

Para cambiar esto, edita en `workspace-state-manager.sh` línea ~175:
```bash
if [ $state_age -lt 600 ]; then  # 600 segundos = 10 minutos
```

### Identificación de ventanas
El sistema identifica ventanas por:
- Clase de la aplicación (`class`)
- Clase inicial (`initialClass`)
- Título de la ventana (`title`)

Funciona con la mayoría de aplicaciones: Firefox, Kitty, VSCode, Windsurf, Discord, etc.

## 📚 Documentación Completa

Lee la documentación completa en:
`~/.config/hypr/scripts/README-workspace-state.md`

## 🎉 Beneficios

- ✅ **Ahorra tiempo** - No más reorganizar ventanas después de usar el KVM
- ✅ **Automático** - Funciona sin intervención manual
- ✅ **Confiable** - Guarda backups y valida estados
- ✅ **Flexible** - Puedes usar comandos manuales cuando quieras
- ✅ **Seguro** - Solo restaura estados recientes (< 10 min)

---

**¡El sistema ya está funcionando! La próxima vez que uses el KVM, tus workspaces se restaurarán automáticamente.**
