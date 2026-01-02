import app from "ags/gtk4/app";
import Bar from "./widgets/bar/Bar";
import { getCssPath } from "./utils/scss";
import RightPanel from "./widgets/rightPanel/RightPanel";
import RightPanelHover from "./widgets/rightPanel/RightPanelHover";
import NotificationPopups from "./widgets/NotificationPopups";
import AppLauncher from "./widgets/AppLauncher";
import Progress from "./widgets/Progress";
import UserPanel from "./widgets/UserPanel";
import WallpaperSwitcher from "./widgets/WallpaperSwitcher";
import SettingsWidget from "./widgets/leftPanel/components/SettingsWidget";
import BarHover from "./widgets/bar/BarHover";
import OSD from "./widgets/OSD";
import { getMonitorName } from "./utils/monitor";
import { logTime } from "./utils/time";
import LeftPanel from "./widgets/leftPanel/LeftPanel";
import LeftPanelHover from "./widgets/leftPanel/LeftPanelHover";
import { compileBinaries } from "./utils/gcc";
// import "./services/autoSwitchWorkspace";
import ScreenShot from "./widgets/ScreenShot";

// Global flag to prevent multiple initializations
let displayInitialized = false;

const perMonitorDisplay = () => {
  if (displayInitialized) {
    print("\t WARNING: perMonitorDisplay already initialized, skipping...");
    return;
  }
  displayInitialized = true;

  const monitors = app.get_monitors();
  print(`\t TOTAL MONITORS DETECTED: ${monitors.length}`);

  monitors.forEach((monitor, index) => {
    try {
      const monitorName = getMonitorName(monitor.get_display(), monitor);
      print(`\t MONITOR ${index}: ${monitorName}`);

    // Only create NotificationPopups for the primary monitor (eDP-1) to avoid duplicates
    const isMainMonitor = monitorName === "eDP-1" || index === 0;

    // List of widget initializers
    const widgetInitializers = [
      { name: "Bar", fn: () => Bar(monitor) },
      { name: "BarHover", fn: () => BarHover(monitor) },
      // { name: "Progress", fn: () => Progress(monitor) },
      { name: "RightPanel", fn: () => RightPanel(monitor) },
      { name: "RightPanelHover", fn: () => RightPanelHover(monitor) },
      { name: "LeftPanel", fn: () => LeftPanel(monitor) },
      { name: "LeftPanelHover", fn: () => LeftPanelHover(monitor) },
      // Only create NotificationPopups on main monitor to prevent duplicates
      ...(isMainMonitor ? [{ name: "NotificationPopups", fn: () => NotificationPopups(monitor) }] : []),
      { name: "AppLauncher", fn: () => AppLauncher(monitor) },
      { name: "UserPanel", fn: () => UserPanel(monitor) },
      { name: "WallpaperSwitcher", fn: () => WallpaperSwitcher(monitor) },
      // { name: "MediaPopups", fn: () => MediaPopups(monitor) },
      // { name: "SettingsWidget", fn: () => SettingsWidget(monitor) },
      // { name: "OSD", fn: () => OSD(monitor) },
      // { name: "ScreenShot", fn: () => ScreenShot(monitor) },
    ];

    // Launch each widget independently without waiting
    widgetInitializers.forEach(({ name, fn }) => {
      try {
        logTime(`\t\t ${name}`, fn);
      } catch (widgetError) {
        print(`\t\t ERROR in widget ${name}: ${widgetError}`);
      }
    });
    } catch (e) {
      print(`\t ERROR on monitor ${index}: ${e}`);
    }
  });
};

app.start({
  css: getCssPath(),
  main: () => {
    // logTime("\t Compiling Binaries", () => compileBinaries());
    perMonitorDisplay();
  },
});
