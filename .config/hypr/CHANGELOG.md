# Changelog

## [Unreleased]

### Fixed

- **Clipboard Monitor Integer Comparison Error** (5f7ab1b)
  - Fixed bash integer comparison error in `start-clipboard-monitor.sh` and `check-clipboard-monitor.sh`
  - **Root Cause:** `pgrep -fc` was returning multi-line output ("0\n0") instead of single integer
  - **Solution:** Refactored process counting logic to use robust pattern:
    - Get PIDs first with `pgrep -f`
    - Check if output is empty, set count to 0
    - Otherwise use `wc -l | xargs` to get clean integer count
  - Fixed trap cleanup issue where EXIT trap was triggering prematurely during `exec`
  - Added proper trap removal before `exec wl-paste` to prevent spurious cleanup
  - All integer comparisons now work correctly without "[: X\nY: integer expected" errors

- **COMPLETE REFACTOR: Clipboard Monitor Duplicate Notifications** (1330482)
  - **Root Cause:** Multiple wl-paste processes (3+) were being launched at startup, causing triple notifications
  - **Solution:** Completely refactored clipboard monitoring system with unified architecture
  - **Changes:**
    - Rewrote `start-clipboard-monitor.sh` with multi-layer singleton protection:
      - Atomic lock acquisition using `mkdir` 
      - Aggressive cleanup of ALL existing wl-paste processes on startup
      - PID file validation with stale process detection
      - Race condition prevention with verification delays
      - Comprehensive startup logging to `/tmp/clipboard-monitor-startup.log`
    - Simplified `exec.conf` to use ONLY the launcher script (removed all inline implementations)
    - Created `check-clipboard-monitor.sh` health check script for diagnostics
    - Cleared all previous partial fixes from older commits
  - **Multimonitor Compatibility:** Works across all monitor configurations (clipboard is compositor-level, not per-monitor)
  - **Guaranteed:** System now prevents multiple instances at boot/login and during hotplug events

### Added

- **Complete English Translation** (07073f9)
  - Translated all Spanish documentation to English (COMANDOS-UPDATE.md, FORK-SYNC-GUIDE.md, README-SYNC.md)
  - Translated all script comments and messages to English (sync-upstream.sh, sync-upstream-auto.sh)
  - Enhanced .gitignore with backup file exclusion patterns (*.backup.*, *.bak, *~)

- **Clipboard Monitor Diagnostics**
  - New `check-clipboard-monitor.sh` script for system health verification
  - Shows process count, PID status, lock status, and recent activity logs
  - Provides clear status verdict (HEALTHY/UNHEALTHY/NOT RUNNING)

### Added (Previous)

- **Automated Upstream Synchronization Tools** (6d9a16d)
  - `sync-upstream.sh` script with interactive options (merge/rebase/auto)
  - `sync-upstream-auto.sh` for fully automated synchronization
  - GitHub Action for daily automatic upstream sync
  - Conflict resolution and stash management
  - Support for handling non-fast-forward pushes automatically
  - Complete documentation in `FORK-SYNC-GUIDE.md`, `README-SYNC.md`, and `COMANDOS-UPDATE.md` (848fa5d)
  - Integration with existing `UPDATE.sh --dev --fork` workflow (848fa5d)
- Comprehensive multi-monitor support with automatic device detection
- `multi-monitor-manager.sh` script for intelligent monitor management
- `refresh-rate-manager.sh` script for dynamic refresh rate management (f4a6e40)
- Interactive refresh rate selection with terminal-based menus (f4a6e40)
- Direct refresh rate keybinds for 60/75/120/144Hz (f4a6e40)
- Comprehensive English documentation in `MULTI_MONITOR_KEYBINDS.md` (f4a6e40)
- Automatic device type detection (laptop/desktop)
- Intelligent lid event handling for laptops
- Automatic resolution configuration for secondary monitors
- Enhanced keybinds for moving workspaces between monitors
- `lid-handler.sh` script for automatic lid events
- `monitor-setup.sh` script for common quick configurations
- `monitor-hotplug.sh` script for automatic monitor hotplug detection
- `move-window-monitor.sh` script for dynamic window movement between monitors
- systemd service `hyprland-lid-handler.service` for automatic event handling
- systemd service `hyprland-monitor-hotplug.service` for monitor hotplug detection
- `multi-monitor-keybinds.conf` configuration file with specialized keybinds
- Complete documentation in `README-MultiMonitor.md`

### Changed

- Updated `hyprland.conf` to include multi-monitor configuration
- Modified `configs/exec.conf` for startup auto-configuration
- Enhanced `configs/monitors.conf` with automatic generation

### Fixed

- **Triple Notification Bug on Single Monitor**
  - Fixed clipboard monitor spawning 3 duplicate instances causing triple notifications
  - Added singleton protection with lock file mechanism in exec.conf
  - Implemented global flag in AGS app.ts to prevent multiple display initializations
  - Added singleton pattern in NotificationPopups.tsx to prevent duplicate notification listeners
  - Resolved issue where hyprctl reload was re-executing exec-once commands
- **Package Manager Process Cleanup** (6b2a781)
  - Fixed hanging pkill processes that could freeze UPDATE.sh script
  - Replaced problematic `pkill -f` commands with targeted PID-based cleanup
  - Added graceful termination (TERM) before force kill (KILL -9)
  - Created standalone `cleanup-pacman.sh` script for manual cleanup
  - Added preventive cleanup to sync scripts
- Fixed keybind syntax errors in multi-monitor configuration
- Corrected dispatcher commands for window and workspace movement
- Fixed AGS bar not appearing on external monitors
- Fixed pkill command to avoid killing other applications (like Windsurf)
- Added automatic AGS restart when monitor configuration changes
- Added automatic monitor hotplug detection for seamless AGS bar management
- Fixed window movement keybinds to work dynamically with any monitor configuration
- Fixed multi-monitor keybinds by adding missing variable definitions (f4a6e40)
- Removed duplicate configuration includes in hyprland.conf (f4a6e40)
- Improved monitor mode selection with numerical interface (f4a6e40)
- Fixed interactive menu terminal exit when showing current configuration (f7db23c)

### Features

- **Automatic Detection**: Identifies laptops vs desktops automatically
- **Smart Lid Management**: When lid closes with AC power and external monitor connected:
  - Disables internal monitor
  - Moves all workspaces to external monitor
  - Prevents system suspension
- **Workspace Redistribution**: Automatically distributes workspaces across monitors
- **Resolution Configuration**: Easy interface for configuring secondary monitor resolutions
- **Advanced Keybinds**: 
  - `Super + Alt + →/←`: Move current workspace between monitors
  - `Super + Shift + Alt + →/←`: Move active window between monitors
  - `Super + Ctrl + Alt + →/←`: Focus between monitors
  - `Super + Shift + M`: Open interactive multi-monitor manager
  - `Super + Shift + P`: Mirror mode for presentations
  - `Super + Shift + I`: Toggle internal monitor
  - `Super + Shift + R`: Interactive refresh rate manager (f4a6e40)
  - `Super + Alt + F1-F4`: Direct refresh rate changes (60/75/120/144Hz) (f4a6e40)
- **Refresh Rate Management**: Intelligent refresh rate switching with:
  - Automatic detection of available refresh rates
  - Position preservation during rate changes
  - Interactive terminal-based selection menu
  - Notification support for configuration changes (f4a6e40)
- **Enhanced User Experience**: Improved interactive menus with:
  - Persistent menu loops that don't exit unexpectedly
  - Clear screen transitions between operations
  - "Press Enter to continue" prompts for better flow (f7db23c)

## [2025-09-06]

### Added

- Initial implementation of multi-monitor support for ArchEclipse Rice
- Complete system for automatic monitor detection and configuration
- Intelligent laptop event handling (lid close/open)
- Management and automated configuration scripts
- Specialized keybindings for multi-monitor workflows
- Complete system documentation
