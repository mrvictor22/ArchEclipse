# Fork Modifications Registry

Este archivo documenta TODOS los archivos modificados en el fork que difieren de upstream.
**IMPORTANTE**: Revisar este archivo antes de cherry-pick de upstream para evitar conflictos.

## Archivos Modificados

### AGS - Configuración

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `constants/app.constants.ts` | `getFileManagerCommand()` helper | File Manager Selector dinámico |
| `constants/settings.constants.ts` | `fileManager: "nautilus"`, `lock: true` | Default para selector + paneles con lock por defecto |
| `interfaces/settings.interface.ts` | `fileManager: string` | Tipo para selector |
| `scripts/search-booru.py` | Null safety en r.json() | Fix crashes cuando API falla |

### AGS - Widgets

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `widgets/leftPanel/components/SettingsWidget.tsx` | `FileManagerSelector` component | Selector de file manager en Settings |
| `widgets/rightPanel/components/Notification.tsx` | Null check antes de .endsWith() | Fix crash con notificaciones sin icono |
| `widgets/Picture.tsx` | `null` en vez de `undefined` | GTK no acepta undefined para file |
| `classes/BooruImage.tsx` | Layout fix + Array.isArray() check | Actions debajo de imagen (no overlay) + Fix readJson null |
| `widgets/leftPanel/components/BooruViewer.tsx` | Array.isArray() check | Fix readJson null |
| `widgets/Player.tsx` | coverArt fallback | Fix null coverArt |

### Maintenance - Scripts Protegidos

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `maintenance/UPDATE.sh` | **Reescritura completa del fork** (~1079 líneas) | Soporte `--all`/`--quick`/`--help`, multi-gestor (pacman/yay/paru/flatpak/snap/pip), colores, contadores. **NO hace `git reset --hard`** (seguro para forks). Solo tocar si upstream agrega scripts/funcionalidad esencial para el rice. |

> **CRÍTICO**: El UPDATE.sh de upstream hace `git reset --hard origin/$BRANCH` que **destruye todos los cambios del fork**. NUNCA reemplazar con la versión de upstream.

### Hyprland - Scripts (Únicos del fork)

| Archivo | Descripción |
|---------|-------------|
| `scripts/monitor-hotplug.sh` | Detección automática de monitores |
| `scripts/lid-handler.sh` | Manejo de tapa del laptop. `acpi_listen_works()` verifica acpid antes de usar, fallback polling 2s. Evalúa estado al arrancar (no solo cambios). |
| `scripts/multi-monitor-manager.sh` | Gestión central de monitores. `get_btop_workspace()` detecta por PID. `generate_monitor_config()` respeta lid state (disable eDP + offset 0x0). `REQUIRE_AC_FOR_LID_ACTION` configurable. `INTERNAL_MONITOR_FALLBACK` para re-enable post-disable. |
| `scripts/setup-lid-handler.sh` | Setup script (sudo) para logind override + acpid. **NO reinicia logind** (mata sesión Hyprland). |
| `scripts/workspace-state-manager.sh` | Preservación de estado (KVM) |
| `scripts/start-clipboard-monitor.sh` | Lanzador singleton clipboard |
| `scripts/clipboard-monitor.sh` | Notificaciones de clipboard |
| `scripts/check-clipboard-monitor.sh` | Diagnóstico de clipboard |

### Hyprland - Configs

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `configs/exec.conf` | LD_PRELOAD para AGS | Fix gtk4-layer-shell |
| `configs/multi-monitor-keybinds.conf` | Keybinds para monitores (foot) | Único del fork. Migrado kitty→foot (f1d24e1) |

### Hyprland - Wallpaper Daemon (Único del fork)

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `scripts-c/hyprpaper-loop.c` | Fallback `w-default=` + silenciar notify-send para workspaces sin config | Workspaces 11+ causaban spam de notificaciones de error |
| `hyprpaper/config/defaults.conf` | Entrada `w-default=` (template) | Soporte para fallback wallpaper |
| `hyprpaper/config/{monitor}/defaults.conf` | Entrada `w-default=` con wallpaper de w-1 | Configs locales (no tracked) |

### Documentación (Única del fork)

- `CLAUDE.md`
- `docs/*.md`
- `.claude/*`

## Commits de Upstream Incorporados (2026-01-05)

| Commit | Descripción | Notas |
|--------|-------------|-------|
| `7bcbdb00` | Animation keyframes | Sin conflictos |
| `1c8f1fb7` | Monitor name retrieval | **Ayman incorporó nuestro fix de get_connector()!** |
| `d304fd97` | Notification handling | Corregimos bug de null check |

## Procedimiento de Cherry-Pick Seguro

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Ver commits nuevos
git log --oneline HEAD..upstream/master

# 3. Para CADA commit que quieras:
git show <hash> --stat

# 4. Verificar si toca archivos de esta lista
#    Si SÍ toca → revisar manualmente el diff
#    Si NO toca → cherry-pick seguro

# 5. Cherry-pick
git cherry-pick <hash>

# 6. Si hay conflicto en archivo de esta lista:
#    - Resolver manualmente preservando TUS cambios
#    - git add <archivo>
#    - git cherry-pick --continue
```

## PRs Enviados a Upstream

| PR | Título | Estado |
|----|--------|--------|
| #193 | fix(ags): use get_connector() for reliable multi-monitor support | ✅ Merged |
| #195 | feat(settings): add file manager selector with auto-detection | ⏳ Pending |

## Última actualización

- Fecha: 2026-02-26
- Último commit de upstream revisado: merge `f222c00`
- `f1d24e1`: fix btop detection (PID), wallpaper daemon w-default fallback, kitty→foot keybinds
- Lid handler overhaul: logind override, acpi_listen validation, lid-aware monitor config, hotplug/lid conflict resolution
