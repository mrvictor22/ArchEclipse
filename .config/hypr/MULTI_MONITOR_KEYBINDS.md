# Multi-Monitor Keybinds Reference

## 🎯 **Refresh Rate Commands**

### Direct Refresh Rate Change (External Monitor HDMI-A-1)
| Keybind | Function |
|---------|---------|
| `Super + Alt + F1` | **60Hz** |
| `Super + Alt + F2` | **75Hz** |
| `Super + Alt + F3` | **120Hz** |
| `Super + Alt + F4` | **144Hz** |

### Smart Refresh Rate Manager
| Keybind | Function |
|---------|---------|
| `Super + Shift + R` | **Interactive menu** to select refresh rate |

---

## 🖥️ **Multi-Monitor Management**

### Interactive Menus
| Keybind | Function |
|---------|---------|
| `Super + Shift + M` | **Main menu** multi-monitor |
| `Super + Ctrl + Shift + M` | **Auto-configure** monitors |
| `Super + Alt + Shift + M` | **Redistribute** workspaces |

### Quick Configuration
| Keybind | Function |
|---------|---------|
| `Super + Shift + E` | **Detect** external monitor |
| `Super + Shift + X` | **Extended mode** (default) |
| `Super + Shift + P` | **Mirror mode** (presentations) |
| `Super + Shift + I` | **Toggle** internal monitor |
| `Super + Shift + F12` | **Show current status** |

---

## 🔄 **Workspace Management**

### Move Workspace Between Monitors
| Keybind | Function |
|---------|---------|
| `Super + Alt + →` / `Super + Alt + N` | Move workspace to **next** monitor |
| `Super + Alt + ←` / `Super + Alt + H` | Move workspace to **previous** monitor |

### Move Window Between Monitors
| Keybind | Function |
|---------|---------|
| `Super + Ctrl + Shift + →` / `Super + Ctrl + Shift + N` | Move window to **next** monitor |
| `Super + Ctrl + Shift + ←` / `Super + Ctrl + Shift + H` | Move window to **previous** monitor |

### Focus Monitor
| Keybind | Function |
|---------|---------|
| `Super + Ctrl + Alt + →` / `Super + Ctrl + Alt + N` | Focus **next** monitor |
| `Super + Ctrl + Alt + ←` / `Super + Ctrl + Alt + H` | Focus **previous** monitor |

### Specific Workspace to Monitor
| Keybind | Function |
|---------|---------|
| `Super + Alt + F1-F10` | Move specific workspace to specific monitor |
| `Super + Ctrl + Shift + S` | **Swap** workspaces between monitors |

---

## 🛠️ **Available Scripts**

### Manual Usage from Terminal

```bash
# Multi-monitor manager
~/.config/hypr/scripts/multi-monitor-manager.sh
~/.config/hypr/scripts/multi-monitor-manager.sh auto
~/.config/hypr/scripts/multi-monitor-manager.sh status
~/.config/hypr/scripts/multi-monitor-manager.sh redistribute

# Refresh rate manager
~/.config/hypr/scripts/refresh-rate-manager.sh
~/.config/hypr/scripts/refresh-rate-manager.sh status
~/.config/hypr/scripts/refresh-rate-manager.sh set HDMI-A-1 120
~/.config/hypr/scripts/refresh-rate-manager.sh cycle
```

---

## 📋 **Current System Status**

- **Internal Monitor**: eDP-1 (1920x1200@60Hz)
- **External Monitor**: HDMI-A-1 (2560x1440@Variable Hz)
- **Available Rates**: 30, 50, 56, 60, 66, 70, 72, 75, 120Hz
- **Position**: External monitor to the right of internal

---

## ✅ **Functionality Verification**

To verify everything works correctly:

1. **Test main menu**: `Super + Shift + M`
2. **Test refresh rate change**: `Super + Alt + F3` (120Hz)
3. **Test refresh rate menu**: `Super + Shift + R`
4. **Verify status**: `Super + Shift + F12`

---

*Last updated: 2025-09-28*
