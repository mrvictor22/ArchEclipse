# Power Management System

Sistema de gestión de energía para ThinkPad con AMD Ryzen, integrado con ArchEclipse rice.

## Componentes

### 1. PowerWidget (AGS)
Widget en el panel izquierdo para control manual de perfiles de energía.

**Ubicación:** `~/.config/ags/widgets/leftPanel/components/PowerWidget.tsx`

**Funciones:**
- Selector de perfiles: `performance`, `balanced`, `low-power`
- Monitoreo de temperatura y frecuencia CPU
- Control de límite térmico vía RyzenAdj
- Indicador de AC/Batería

### 2. Power Profile Manager
Script que gestiona automáticamente los perfiles según AC/batería.

**Ubicación:** `~/.config/hypr/scripts/power-profile-manager.sh`

**Uso:**
```bash
# Aplicar perfil automáticamente según AC/batería
./power-profile-manager.sh auto

# Forzar perfil específico
./power-profile-manager.sh performance
./power-profile-manager.sh balanced
./power-profile-manager.sh low-power

# Ver estado actual
./power-profile-manager.sh status
```

**Configuración** (editar el script):
```bash
AC_PROFILE="performance"      # Perfil con cargador
BATTERY_PROFILE="balanced"    # Perfil con batería
THERMAL_LIMIT_AC=95           # Límite térmico con AC (°C)
THERMAL_LIMIT_BATTERY=85      # Límite térmico con batería (°C)
```

### 3. Servicio Systemd
Aplica el perfil correcto al iniciar el sistema.

**Ubicación:** `~/.config/hypr/scripts/power-profile.service`

### 4. Udev Rules
Detecta conexión/desconexión del cargador y cambia el perfil automáticamente.

**Ubicación:** `~/.config/hypr/scripts/99-power-profile.rules`

## Instalación

```bash
# Copiar servicio systemd
sudo cp ~/.config/hypr/scripts/power-profile.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now power-profile.service

# Copiar udev rules
sudo cp ~/.config/hypr/scripts/99-power-profile.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

## Perfiles disponibles

| Perfil | TDP (STAPM) | Uso |
|--------|-------------|-----|
| `performance` | ~30W | Máximo rendimiento, conectado a AC |
| `balanced` | ~15W | Uso normal, balance rendimiento/batería |
| `low-power` | ~10W | Máximo ahorro de batería |

## Requisitos

- ThinkPad con soporte para `platform_profile` (verificar con `cat /sys/firmware/acpi/platform_profile_choices`)
- `ryzenadj` (opcional, para control de límite térmico)

## Verificación

```bash
# Ver perfil actual
cat /sys/firmware/acpi/platform_profile

# Ver perfiles disponibles
cat /sys/firmware/acpi/platform_profile_choices

# Ver TDP actual (requiere ryzenadj)
sudo ryzenadj --info | grep STAPM

# Ver logs del servicio
journalctl -t power-profile-manager -f
```

## Notas técnicas

- En ThinkPads con AMD Ryzen, el TDP (STAPM) se controla mejor vía `platform_profile` del kernel Linux que con `ryzenadj --stapm-limit`
- `ryzenadj` sigue siendo útil para el límite térmico (`--tctl-temp`)
- El sistema usa ACPI de Lenovo para cambiar los perfiles de energía

## Troubleshooting

**El perfil no cambia al conectar/desconectar cargador:**
```bash
# Verificar que las udev rules estén instaladas
ls -la /etc/udev/rules.d/99-power-profile.rules

# Recargar udev
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**El servicio no inicia:**
```bash
# Ver logs
journalctl -u power-profile.service -e

# Verificar que el script tiene permisos
chmod +x ~/.config/hypr/scripts/power-profile-manager.sh
```
