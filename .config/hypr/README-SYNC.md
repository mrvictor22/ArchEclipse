# 🔄 Fork Sync Tools - Referencia Rápida

Herramientas para mantener tu fork sincronizado con el repositorio upstream de Ayman.

## 🚀 Comandos Principales

### ✅ **Para Actualizar Manteniendo TUS Cambios (RECOMENDADO)**

```bash
# Sincronización automática (recomendado para uso diario)
./sync-upstream-auto.sh

# Sincronización interactiva (más control)
./sync-upstream.sh

# Verificar actualizaciones disponibles
git fetch upstream && git log --oneline HEAD..upstream/master
```

### ❌ **NUNCA Uses Estos Comandos (Perderías tus cambios)**

```bash
# ❌ PELIGROSO - Te lleva solo al upstream SIN tus mejoras
git checkout upstream/master
git reset --hard upstream/master
git pull upstream master  # Sin merge apropiado
```

## 📋 Opciones del Script Interactivo

1. **Merge** - Preserva historial completo
2. **Rebase** - Historial más limpio  
3. **Automático** - Detecta la mejor estrategia

## 🤖 Automatización

- **GitHub Action**: Se ejecuta diariamente a las 2:00 AM UTC
- **Ejecución manual**: Desde GitHub Actions tab
- **Script automático**: `./sync-upstream-auto.sh`

## ⚡ Comandos de Emergencia

```bash
git merge --abort              # Abortar merge problemático
git stash pop                  # Restaurar cambios guardados
git status                     # Ver estado actual
git remote -v                  # Verificar remotos configurados
```

## 📖 Documentación Completa

Ver `FORK-SYNC-GUIDE.md` para documentación detallada con ejemplos y resolución de problemas.

---

**Upstream**: [AymanLyesri/ArchEclipse](https://github.com/AymanLyesri/ArchEclipse)  
**Tu Fork**: [mrvictor22/ArchEclipse](https://github.com/mrvictor22/ArchEclipse)
