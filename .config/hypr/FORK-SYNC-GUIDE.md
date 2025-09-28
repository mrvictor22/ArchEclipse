# 🔄 Guía de Sincronización de Fork

Esta guía explica cómo usar las herramientas de sincronización automática para mantener tu fork actualizado con el repositorio upstream de Ayman.

## 📋 Herramientas Disponibles

### 1. `sync-upstream.sh` - Script Interactivo
Script con opciones interactivas para diferentes estrategias de sincronización.

### 2. `sync-upstream-auto.sh` - Script Automático
Script completamente automático que no requiere interacción del usuario.

### 3. GitHub Action - Sincronización Diaria
Acción automática que se ejecuta diariamente para mantener el fork actualizado.

---

## 🚀 Comandos de Uso

### Sincronización Interactiva

```bash
# Ejecutar script interactivo
./sync-upstream.sh

# Opciones disponibles:
# 1) Merge (preserva historial completo)
# 2) Rebase (historial más limpio)  
# 3) Automático (detecta la mejor opción)
```

### Sincronización Automática

```bash
# Ejecutar sincronización completamente automática
./sync-upstream-auto.sh

# Este script:
# - Guarda cambios locales en stash automáticamente
# - Detecta la mejor estrategia (merge/rebase)
# - Resuelve conflictos automáticamente
# - Maneja errores de push
# - Restaura cambios locales al final
```

### Verificación Manual

```bash
# Verificar si hay actualizaciones disponibles (sin aplicar)
git fetch upstream && git log --oneline HEAD..upstream/master

# Ver diferencias antes de sincronizar
git fetch upstream && git diff HEAD upstream/master

# Verificar estado actual del repositorio
git status

# Ver historial de commits
git log --oneline --graph --all -10
```

### Comandos de Emergencia

```bash
# Si algo sale mal, abortar merge en progreso
git merge --abort

# Si hay conflictos, ver archivos afectados
git diff --name-only --diff-filter=U

# Restaurar desde stash si es necesario
git stash list
git stash pop

# Forzar push si es necesario (usar con cuidado)
git push origin master --force-with-lease
```

---

## 🔧 Configuración Inicial

### Verificar Configuración de Remotos

```bash
# Ver remotos configurados
git remote -v

# Debería mostrar:
# origin    https://github.com/mrvictor22/ArchEclipse.git (fetch)
# origin    https://github.com/mrvictor22/ArchEclipse.git (push)
# upstream  https://github.com/AymanLyesri/ArchEclipse.git (fetch)
# upstream  https://github.com/AymanLyesri/ArchEclipse.git (push)
```

### Si Upstream No Está Configurado

```bash
# Agregar upstream remoto
git remote add upstream https://github.com/AymanLyesri/ArchEclipse.git

# Verificar que se agregó correctamente
git remote -v
```

---

## 📊 Flujo de Trabajo Recomendado

### Uso Diario

1. **Verificación rápida** (opcional):
   ```bash
   git fetch upstream && git log --oneline HEAD..upstream/master
   ```

2. **Sincronización automática**:
   ```bash
   ./sync-upstream-auto.sh
   ```

### Uso Semanal

1. **Sincronización interactiva** para mayor control:
   ```bash
   ./sync-upstream.sh
   ```

2. **Seleccionar estrategia** según tus necesidades:
   - **Merge**: Si quieres preservar todo el historial
   - **Rebase**: Si prefieres un historial más limpio
   - **Automático**: Deja que el script decida

---

## 🤖 GitHub Action - Sincronización Automática

### Configuración

La GitHub Action está configurada en `.github/workflows/sync-upstream.yml` y:

- **Se ejecuta automáticamente** todos los días a las 2:00 AM UTC
- **Se puede ejecutar manualmente** desde la pestaña "Actions" en GitHub
- **Usa estrategia de merge** para preservar historial
- **Hace push automático** de los cambios

### Ejecutar Manualmente desde GitHub

1. Ve a tu repositorio en GitHub
2. Haz clic en la pestaña "Actions"
3. Selecciona "Sync Upstream"
4. Haz clic en "Run workflow"
5. Confirma con "Run workflow"

---

## ⚠️ Resolución de Problemas

### Error: "non-fast-forward"

```bash
# El script automático maneja esto, pero si ocurre manualmente:
git fetch origin
git merge origin/master --no-edit
git push origin master
```

### Conflictos de Merge

```bash
# Ver archivos en conflicto
git status

# Para cada archivo en conflicto, elegir una estrategia:
git checkout --ours archivo.conf    # Mantener tu versión
git checkout --theirs archivo.conf  # Aceptar versión upstream

# Marcar como resuelto y completar merge
git add archivo.conf
git commit --no-edit
```

### Stash con Conflictos

```bash
# Si hay conflictos al restaurar stash
git stash list
git stash show stash@{0}

# Resolver conflictos manualmente y luego:
git stash drop stash@{0}
```

---

## 📈 Monitoreo y Logs

### Ver Últimos Cambios Sincronizados

```bash
# Ver commits recientes
git log --oneline -10

# Ver cambios específicos de upstream
git log --oneline upstream/master -5

# Ver diferencias entre tu fork y upstream
git log --oneline --left-right HEAD...upstream/master
```

### Verificar Estado de Sincronización

```bash
# Verificar si estás actualizado
git fetch upstream
git status

# Ver cuántos commits estás adelante/atrás
git rev-list --count HEAD..upstream/master  # Atrás
git rev-list --count upstream/master..HEAD  # Adelante
```

---

## ⚠️ **IMPORTANTE: Diferencia entre Update Normal vs Fork Update**

### ❌ **Update "Normal" (PELIGROSO para forks)**
```bash
# ESTOS COMANDOS TE LLEVAN SOLO AL UPSTREAM SIN TUS CAMBIOS
git checkout upstream/master     # ❌ Pierdes tus mejoras
git reset --hard upstream/master # ❌ Pierdes tus mejoras  
git pull upstream master         # ❌ Sin merge apropiado
```
**⚠️ Estos comandos ELIMINARÍAN todas tus mejoras, scripts y configuraciones personalizadas!**

### ✅ **Fork Update Correcto (Mantiene tus cambios)**
```bash
# ESTOS SON LOS COMANDOS CORRECTOS PARA TU FORK
./sync-upstream-auto.sh          # ✅ Automático, mantiene tus cambios
./sync-upstream.sh               # ✅ Interactivo, mantiene tus cambios
```

### 🔍 **¿Por qué la diferencia?**

- **Tu fork** tiene mejoras adicionales (scripts de sync, documentación, configuraciones)
- **Upstream** solo tiene los cambios base de Ayman
- **Los scripts de sync** combinan ambos: upstream + tus mejoras
- **Update normal** te llevaría solo al estado base, perdiendo tu trabajo

### 📊 **Estado Actual de tu Fork:**
```bash
# Tu fork incluye:
- Cambios base de Ayman (upstream)
- Scripts de sincronización automática
- Documentación completa
- Configuraciones personalizadas
- Mejoras en multi-monitor
- Y mucho más...
```

## 🎯 Mejores Prácticas

1. **SIEMPRE usa los scripts de sync** para actualizar
2. **NUNCA uses git reset --hard upstream/master**
3. **Ejecuta sincronización regularmente** (diario o semanal)
4. **Usa el script automático** para uso rutinario
5. **Usa el script interactivo** cuando quieras más control
6. **Verifica cambios** antes de sincronizar si tienes trabajo importante
7. **Mantén commits locales organizados** para evitar conflictos
8. **Usa branches** para desarrollo experimental

---

## 📞 Soporte

Si encuentras problemas:

1. **Revisa los logs** del script para entender qué pasó
2. **Usa comandos de verificación** para diagnosticar el estado
3. **Consulta esta guía** para comandos de emergencia
4. **En caso extremo**, haz backup de tus cambios y clona fresh

---

*Última actualización: 2025-09-28*
*Versión de herramientas: 6d9a16d*
