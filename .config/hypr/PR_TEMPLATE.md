# Pull Request: Hyprland 0.51.0 Gestures Compatibility Fix

## 🎯 Objetivo

Corregir errores de configuración causados por la eliminación de opciones `workspace_swipe` en Hyprland 0.51.0+.

## 🐛 Problema

En Hyprland 0.51.0, las opciones de configuración `workspace_swipe*` fueron eliminadas, causando errores como:
```
Config error: config option <gestures:workspace_swipe> does not exist
```

## ✅ Solución

### Cambios realizados:

1. **`configs/general.conf`**:
   - Comenté la sección `gestures` deprecated
   - Agregué documentación explicativa
   - Preservé configuración original como referencia

2. **`configs/keybinds.conf`**:
   - Implementé nuevos gesture binds:
     ```
     gesture = 3, horizontal, workspace
     gesture = 3, down, dispatcher, exec, kitty
     gesture = 4, up, dispatcher, fullscreen
     ```

3. **Documentación**:
   - `README_GESTURES_FIX.md` con guía completa
   - Referencias a PR oficial de Hyprland
   - Instrucciones de migración

## 🧪 Testing

- ✅ `hyprctl configerrors` - Sin errores
- ✅ `hyprctl reload` - Recarga exitosa  
- ✅ Gestures funcionando correctamente
- ✅ Compatibilidad con rice existente

## 📚 Referencias

- [Hyprland PR #11490](https://github.com/hyprwm/Hyprland/pull/11490)
- [Hyprland Wiki - Gestures](https://wiki.hyprland.org/Configuring/Binds/#gestures)

## 🔄 Compatibilidad

- ✅ Hyprland 0.51.0+
- ✅ Mantiene funcionalidad de gestures
- ✅ No rompe configuraciones existentes
- ✅ Documentación para migración

---

**Commits incluidos:**
- `feat: add Hyprland 0.51.0 gestures compatibility`
- `docs: add comprehensive gestures fix documentation`

Este PR asegura que el rice funcione correctamente con las versiones más recientes de Hyprland sin perder funcionalidad.
