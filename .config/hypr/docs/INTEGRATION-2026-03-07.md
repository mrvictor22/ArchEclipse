# Plan de Integracion Upstream - 2026-03-07

## Resumen Ejecutivo

- **Upstream**: AymanLyesri/ArchEclipse (47173c8b)
- **Fork**: mrvictor22/ArchEclipse (3be255b)
- **Ultima integracion**: merge f222c00 (2026-02-12)
- **Commits nuevos en upstream**: 45
- **Archivos con diferencias**: 27 (de 66 archivos en comun)
- **Archivos solo en fork**: 48 (intocables)
- **Archivos nuevos en upstream**: 1 (PRESENTATION.sh)

## Cambio Arquitectural Mayor de Ayman

**AGS ahora se compila a binario**:
- Antes: `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so GDK_BACKEND=wayland ags run --gtk 3`
- Ahora: `ags bundle ~/.config/ags/app.tsx /tmp/ags-bin` + `/tmp/ags-bin`

El fork depende del metodo anterior con LD_PRELOAD. Este cambio NO se puede integrar sin verificar que AGS funcione correctamente con el metodo bundle en nuestro sistema. **REQUIERE INVESTIGACION SEPARADA.**

---

## Clasificacion de Archivos por Accion

### SKIP - NO Integrar (protegidos del fork)

| Archivo | Razon |
|---------|-------|
| `maintenance/UPDATE.sh` | 1225 lineas de diff. Ayman reescribio completamente (temp cloning, integrity check, etc). Fork tiene reescritura propia. El de upstream hace `git reset --hard`. |
| `maintenance/INSTALL.sh` | 140 lineas de diff. Refactored con figlet branding, sourcing ESSENTIALS. Fork tiene su version. |
| `maintenance/ESSENTIALS.sh` | 103 lineas de diff. Fuertemente refactored con PRESENTATION.sh. |
| `configs/exec.conf` | PROTEGIDO. Upstream elimina LD_PRELOAD, multi-monitor services, clipboard singleton, onedriver, wayvnc. Fork necesita todo esto. |
| `scripts/bar.sh` | PROTEGIDO. Upstream cambia a `ags bundle` + `/tmp/ags-bin`. Fork necesita LD_PRELOAD + `--gtk 3`. |
| `scripts/screenshot.sh` | PROTEGIDO. Upstream usa grimblast+WebP. Fork usa hyprshot+PNG+latest.png symlink. |
| `scripts/clipboard-monitor.sh` | PROTEGIDO. Upstream simplifica (pierde logging, singleton, truncamiento). Fork tiene version mejorada. |
| `scripts-c/hyprpaper-loop.c` | PROTEGIDO. Upstream elimina w-default fallback y restaura notify_error spam. Fork lo soluciono intencionalmente. |
| `scripts/compile-run-binaries.sh` | Upstream agrega `ags bundle` + `ags-bin`. Fork no usa ese metodo de lanzar AGS. |
| `hyprpaper/config/defaults.conf` | PROTEGIDO. Upstream elimina `w-default=`. Fork lo necesita para fallback. |

### SAFE - Cherry-pick Seguro (cambios beneficiosos, sin conflicto)

| Archivo | Cambio | Commit(s) |
|---------|--------|-----------|
| `configs/general.conf` | Agrega gesture `3, up, dispatcher, togglespecialworkspace` (3-finger up) | Dentro de c7f6942e |
| `configs/window_rules.conf` | Remueve `vlc` de float rules (ya no usa vlc) | c7f6942e |
| `hyprpaper/reload.sh` | Usa `nohup` + `disown` para hyprpaper-loop (mejor practica) | 2e54ec7f |
| `maintenance/PRESENTATION.sh` | **NUEVO** - funciones figlet para branding en scripts | 4e794956 |

### MERGE-MANUAL - Requiere revision humana

| Archivo | Cambio Upstream | Lo que debe preservarse del fork |
|---------|----------------|----------------------------------|
| `configs/keybinds.conf` | Upstream elimina: settings panel bind (SUPER ALT+S), screenshot --all bind (SUPER CTRL SHIFT+A), discretion mode (SUPER SHIFT+D). Cambia screenshot area de SUPER SHIFT+Z a SUPER CTRL SHIFT+S. | Fork tiene SUPER SHIFT+Z para area screenshot (evita conflicto con multi-monitor SUPER CTRL SHIFT+S). Evaluar si queremos remover discretion mode bind y settings panel bind. |
| `configs/plugins/hyprexpo.conf` | Cambia gap_size 1->5, bg_col 000000->111111. **Elimina** nuestras lineas de gesture y `hyprexpo-gesture`. Cambiamos esto en 3be255b para Hyprland 0.54 API. | Preservar nuestra version (3be255b) que ya es compatible con Hyprland 0.54. |
| `.gitignore` | Elimina `backups/` del ignore | Podemos aceptar si no tenemos backups/ |
| `pacman/pkglist.txt` | Cambios menores en lista de paquetes | Revisar que no elimine paquetes que el fork necesita |
| `pacman/install-pkgs.sh` | Cambios menores | Revisar |

### REVIEW - Maintenance scripts menores

| Archivo | Cambio | Evaluacion |
|---------|--------|------------|
| `maintenance/BACKUP.sh` | Probablemente agrega `source PRESENTATION.sh` | Si solo es eso, SKIP (no tenemos PRESENTATION.sh en uso) |
| `maintenance/CONFIGURE.sh` | Similar | Similar |
| `maintenance/DEFAULTS.sh` | Similar | Similar |
| `maintenance/LOCALES.sh` | Similar | Similar |
| `maintenance/SDDM.sh` | Similar | Similar |
| `maintenance/TWEAKS.sh` | Similar | Similar |
| `maintenance/PLUGINS.sh` | Cambios menores | Revisar |
| `maintenance/WALLPAPERS.sh` | 178 lineas de diff - cambios significativos | Revisar detalladamente |

---

## Plan de Ejecucion

### Paso 1: Crear branch de integracion
```bash
git checkout -b integration/upstream-2026-03-07
```

### Paso 2: Aplicar cambios SAFE (cherry-pick o edicion manual)
Los cambios SAFE son tan pequenos que es mejor aplicarlos manualmente.

### Paso 3: Evaluar cambios MERGE-MANUAL
Revisar keybinds.conf y decidir que keybinds queremos conservar/eliminar.

### Paso 4: Documentar cambios no integrados
Actualizar FORK-MODIFICATIONS.md con los nuevos commits revisados.

---

## Commits de Upstream por Categoria

### Maintenance/UPDATE (20 commits) - SKIP
Todos relacionados con reescritura de UPDATE.sh e INSTALL.sh. No integrar.

### AGS-related (0 commits en este repo)
Los archivos AGS (.config/ags/) estan en otro repositorio/directorio, no en este git tree de hypr.

### Configs (2 commits)
- c7f6942e: remove vlc float, add gesture 3-up -> PARCIAL
- 38e6331d: Donations widget (no afecta hypr configs)

### Scripts (4 commits)
- c7f6942e: tweaks en bar.sh, compile-run-binaries.sh -> SKIP (ags bundle)
- 012ec2eb: paths con env vars -> SKIP (afecta bar.sh con ags bundle)
- 2d7ec08a: wallpaper scripts -> revisar
- f28216e4: GLib.get_home_dir() paths -> SKIP (afecta bar.sh)

### Hyprpaper (1 commit)
- 2e54ec7f: nohup en reload.sh -> SAFE

---

## Riesgos Identificados

1. **AGS bundle method**: Ayman migro a compilar AGS como binario. Si eventualmente necesitamos migrar, es un cambio grande que requiere testing.
2. **Hyprexpo gestures**: Nuestro fix para 0.54 es mas correcto que el de upstream. No revertir.
3. **Clipboard monitor**: Upstream simplifica mucho, pierde funcionalidad del fork.
4. **Screenshot**: Upstream volvio a grimblast+WebP. Fork mantiene hyprshot+PNG.
5. **exec.conf**: Upstream elimina TODA la infraestructura multi-monitor del fork.

---

## Preguntas Pendientes (retomar despues del refactor AGS)

2. **Nuevos widgets AGS**: Quieres traer SystemResources y/o Donations al fork? (YA SE TRAJERON con la integracion AGS)
3. ~~**booru.py vs search-booru.py**~~: RESUELTO — migrado a booru.py (commit f36f70d0). Upstream incorpora null safety superior.
4. ~~**keybinds.conf**~~: RESUELTO — SUPER CTRL SHIFT+A eliminado (bind muerto, --all no existe). SUPER ALT+S conservado (settings panel funcional). Commit 1550f350.
5. ~~**PRESENTATION.sh + maintenance menores**~~: RESUELTO — 7 maintenance scripts actualizados (figlet+lolcat branding). PRESENTATION.sh skipped (solo usada por INSTALL/UPDATE protegidos). Commit 1c78cba3.
6. ~~**WALLPAPERS.sh**~~: RESUELTO — integrado con menu SFW/NSFW interactivo, tabla de tamaños, UI coloreada. Cleanup automatico DESACTIVADO para proteger wallpapers custom. Commit 836a244e.

---

## Progreso de Integracion

### Commit 1: Hyprland configs SAFE (completado)
- general.conf, window_rules.conf, keybinds.conf, reload.sh, .gitignore, pkglist.txt

### Commit 2: AGS GTK4 Import Refactor (completado - 69ea92aa)
- 86 archivos AGS modificados/agregados
- 76 non-protected files actualizados directo de upstream
- 12 archivos protegidos: imports actualizados, customizaciones preservadas
  - Picture.tsx: null fallback preservado
  - Player.tsx: coverArt fallback preservado
  - Notification.tsx: webp null check preservado
  - BooruViewer.tsx: Array.isArray checks preservados
  - SettingsWidget.tsx: FileManagerSelector + BluetoothToggle preservados
  - Information.tsx: null safety preservado
  - BooruImage.tsx: layout fix preservado
  - PowerWidget.tsx: fork-only (upstream lo elimino), import actualizado
  - CryptoWidget.tsx: fork-only, import actualizado
  - settings.constants.ts, settings.interface.ts: fileManager preservado
- Nuevos widgets de upstream: Donations, SystemResources, CryptoViewer
- Nuevos scripts: booru.py, chatbot.py
- Fork retiene: PowerWidget.tsx (upstream lo elimino)
- search-booru.py eliminado, migrado a booru.py de upstream (f36f70d0)
- Codigo muerto identificado: rightPanel/components/Crypto.tsx (reemplazado por CryptoViewer)

### Commit 7: Limpieza de codigo muerto (completado - be518667)
- Eliminado: MigrationDocsGtk4.md (migracion completada)
- Eliminado: rightPanel/components/Crypto.tsx (reemplazado por CryptoViewer.tsx)
- Eliminado: providers.data.ts (cero imports)
- Eliminado: ags-keystroke-listener.sh (cero referencias)
- Eliminado: get-system-resources.c (reemplazado por system-resources-loop-ags.c)

### Verificacion final de integridad del fork
Todas las features del fork verificadas intactas:
- LD_PRELOAD + --gtk 3 en exec.conf y bar.sh
- hyprshot+PNG en screenshot.sh (no grimblast)
- clipboard-monitor.sh singleton
- w-default fallback en hyprpaper defaults.conf
- Multi-monitor: manager, hotplug, lid-handler, workspace-state
- PowerWidget.tsx (ACPI directo), BluetoothToggle, FileManagerSelector
- Null safety: Picture.tsx, Player.tsx, Notification.tsx, BooruViewer.tsx
- fileManager: string en interface + nautilus default
- power-profile-manager.sh + bluetooth-toggle.sh
- Cero contaminacion: sin ags bundle, sin grimblast, sin git reset --hard
