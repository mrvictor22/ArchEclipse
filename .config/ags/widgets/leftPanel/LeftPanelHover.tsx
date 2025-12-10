import App from "ags/gtk4/app";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { leftPanelLock, setLeftPanelVisibility } from "../../variables";
import { Eventbox } from "../Custom/Eventbox";

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      gdkmonitor={monitor}
      class="LeftPanel"
      application={App}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
    >
      <Eventbox
        onHover={() => {
          if (!leftPanelLock()) setLeftPanelVisibility(true);
        }}
      >
        <box css="min-width: 1px" />
      </Eventbox>
    </window>
  );
};
