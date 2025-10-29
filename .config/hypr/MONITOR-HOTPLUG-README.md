# Monitor Hotplug - Recarga Automática de AGS y Hyperpaper

## 📋 Descripción

Sistema automático de detección de monitores que recarga AGS (barra de estado) y hyperpaper (wallpapers) cuando se conecta o desconecta un monitor externo.

## 🎯 Problema Resuelto

Anteriormente, al conectar/desconectar un monitor externo:
- Las barras de AGS no se cargaban en el monitor externo
- Se producía un consumo excesivo de recursos
- Los wallpapers desaparecían
- Era necesario presionar manualmente `Super + B` para AGS y `Super + W` para recargar wallpapers

## ✅ Solución Implementada

### Detección Automática

El servicio `hyprland-monitor-hotplug.service` ejecuta el script `monitor-hotplug.sh` que:
1. Detecta cambios en la configuración de monitores cada 2 segundos
2. Ejecuta `multi-monitor-manager.sh auto` para reconfigurar monitores
3. Reinicia AGS automáticamente
4. Recarga hyperpaper automáticamente

### Secuencia de Recarga

Cuando se detecta un cambio de monitor:

```
1. Detectar cambio → 2s de espera para estabilizar
2. Reconfigurar monitores (multi-monitor-manager.sh)
3. Esperar 1s
4. Reiniciar AGS
5. Recargar hyperpaper
```

## 🎮 Keybinds

| Combinación | Acción |
|-------------|--------|
| `Super + B` | Reiniciar solo AGS (mantiene funcionalidad original) |
| `Super + Shift + B` | **NUEVO**: Reiniciar AGS y recargar hyperpaper |
| `Super + W` | Abrir selector de wallpapers |

## 🛠️ Uso Manual del Script

El script `monitor-hotplug.sh` ahora soporta varios comandos:

```bash
# Iniciar monitoreo automático (usado por el servicio systemd)
~/.config/hypr/scripts/monitor-hotplug.sh monitor

# Reiniciar solo AGS
~/.config/hypr/scripts/monitor-hotplug.sh restart-ags

# Recargar solo hyperpaper
~/.config/hypr/scripts/monitor-hotplug.sh reload-hyperpaper

# Reiniciar AGS y recargar hyperpaper
~/.config/hypr/scripts/monitor-hotplug.sh reload-all

# Verificar estado actual de monitores
~/.config/hypr/scripts/monitor-hotplug.sh check
```

## 📝 Logs

Los logs del servicio se guardan en:
```
/tmp/hyprland-monitor-hotplug.log
```

Para ver los logs en tiempo real:
```bash
tail -f /tmp/hyprland-monitor-hotplug.log
```

## 🔧 Servicio Systemd

### Estado del Servicio

```bash
# Ver estado
systemctl --user status hyprland-monitor-hotplug.service

# Ver logs del servicio
journalctl --user -u hyprland-monitor-hotplug.service -f
```

### Reiniciar el Servicio

```bash
systemctl --user restart hyprland-monitor-hotplug.service
```

### Deshabilitar/Habilitar

```bash
# Deshabilitar
systemctl --user stop hyprland-monitor-hotplug.service
systemctl --user disable hyprland-monitor-hotplug.service

# Habilitar
systemctl --user enable hyprland-monitor-hotplug.service
systemctl --user start hyprland-monitor-hotplug.service
```

## 🎨 Integración con Hyperpaper

El script utiliza `~/.config/hypr/hyprpaper/reload.sh` para recargar wallpapers, que:
1. Descarga todos los wallpapers cargados
2. Mata el proceso `auto.sh` de cambio automático
3. Ejecuta `load.sh` para recargar wallpapers según la configuración de cada monitor

## ⚡ Rendimiento

- **Intervalo de detección**: 2 segundos
- **Tiempo de espera para estabilización**: 2 segundos después de detectar cambio
- **Tiempo de espera antes de recargar**: 1 segundo después de reconfigurar monitores
- **Total aproximado**: ~3-5 segundos para recarga completa

## 🔍 Troubleshooting

### Las barras no se recargan automáticamente

1. Verificar que el servicio esté corriendo:
   ```bash
   systemctl --user status hyprland-monitor-hotplug.service
   ```

2. Revisar los logs:
   ```bash
   cat /tmp/hyprland-monitor-hotplug.log
   ```

### Los wallpapers no se recargan

1. Verificar que el script de reload tenga permisos de ejecución:
   ```bash
   chmod +x ~/.config/hypr/hyprpaper/reload.sh
   ```

2. Probar recarga manual:
   ```bash
   ~/.config/hypr/scripts/monitor-hotplug.sh reload-hyperpaper
   ```

### Recarga manual de emergencia

Si el sistema automático falla, usa:
```bash
Super + Shift + B
```

## 📚 Archivos Relacionados

- Script principal: `~/.config/hypr/scripts/monitor-hotplug.sh`
- Servicio systemd: `~/.config/systemd/user/hyprland-monitor-hotplug.service`
- Configuración de monitores: `~/.config/hypr/configs/monitors.conf`
- Script de hyperpaper: `~/.config/hypr/hyprpaper/reload.sh`
- Keybinds: `~/.config/hypr/configs/keybinds.conf`

## 🎯 Próximas Mejoras Potenciales

- [ ] Agregar notificaciones al usuario cuando se detecten cambios
- [ ] Configurar el intervalo de detección mediante variable de entorno
- [ ] Agregar soporte para perfiles de monitor predefinidos
- [ ] Implementar modo de bajo consumo con detección menos frecuente
