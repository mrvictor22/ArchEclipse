import { Gtk } from "ags/gtk4";
import { createState } from "ags";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import { notify } from "../../../utils/notification";

const POWER_MODE_SCRIPT = "/home/alphonse/.config/hypr/scripts/power-mode.sh";

interface PowerStatus {
  profile: string;
  governor: string;
  epp: string;
  boost: number;
  curFreq: number;
  maxFreq: number;
  cpuTemp: number;
  acOnline: number;
  mode: string;
}

const defaultStatus: PowerStatus = {
  profile: "balanced",
  governor: "powersave",
  epp: "balance_power",
  boost: 0,
  curFreq: 0,
  maxFreq: 0,
  cpuTemp: 0,
  acOnline: 1,
  mode: "auto",
};

// Power modes for the selector
const powerModes = [
  { id: "performance", name: "Performance", icon: "⚡" },
  { id: "balanced", name: "Auto", icon: "⚖️" },
  { id: "power-saver", name: "Saver", icon: "🔋" },
];

// State
const [status, setStatus] = createState<PowerStatus>(defaultStatus);
const [thermalLimit, setThermalLimit] = createState<number>(90);

let initialized = false;
let currentThermalLimit = 90;

// Refresh all system info via power-mode.sh
const refreshStatus = async () => {
  try {
    const result = await execAsync(`bash -c '${POWER_MODE_SCRIPT} status'`);
    const parsed: PowerStatus = JSON.parse(result.trim());
    setStatus(parsed);
  } catch { /* ignore */ }
};

// Map ACPI profile to our mode IDs
const profileToMode = (profile: string): string => {
  if (profile === "performance") return "performance";
  if (profile === "low-power") return "power-saver";
  return "balanced";
};

// Set power mode via pkexec, verify and show result
const setMode = async (mode: string) => {
  try {
    await execAsync(`sudo ${POWER_MODE_SCRIPT} set ${mode}`);
    // Wait for zen-cpufreq to settle, then verify
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await refreshStatus();
    const s = status.peek();
    notify({
      summary: "Power Mode: " + mode,
      body: `Profile: ${s.profile} · Governor: ${s.governor} · EPP: ${s.epp}`,
    });
  } catch (e) {
    notify({
      summary: "Power Mode Error",
      body: `${e}`,
    });
    await refreshStatus();
  }
};

// Apply thermal limit via pkexec
const applyThermalLimit = async (tctlTemp: number) => {
  try {
    const output = await execAsync(
      `sudo ${POWER_MODE_SCRIPT} thermal ${tctlTemp}`
    );
    await refreshStatus();
    notify({
      summary: "Thermal Limit",
      body: output.trim() || `Set to ${tctlTemp}°C`,
    });
  } catch (e) {
    notify({
      summary: "RyzenAdj Error",
      body: `${e}`,
    });
  }
};

// EPP display names
const eppLabel = (epp: string): string => {
  const map: Record<string, string> = {
    performance: "Performance",
    balance_performance: "Bal. Perf.",
    balance_power: "Bal. Power",
    power: "Power Save",
  };
  return map[epp] || epp;
};

// Mode Selector
const ModeSelector = () => {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <label
        class={"subcategory-label"}
        label={"Power Mode"}
        halign={Gtk.Align.START}
      />
      <box class="setting" spacing={10} hexpand>
        {powerModes.map((mode) => (
          <togglebutton
            hexpand
            class="widget"
            label={mode.name}
            tooltipMarkup={`<b>${mode.name}</b> ${mode.icon}`}
            active={status((s) => profileToMode(s.profile) === mode.id)}
            onToggled={({ active }) => {
              if (active && initialized && profileToMode(status.peek().profile) !== mode.id) {
                setMode(mode.id);
              }
            }}
          />
        ))}
      </box>
    </box>
  );
};

// System Info Display
const SystemInfo = () => {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      {/* Governor + EPP */}
      <box class="setting" hexpand spacing={5}>
        <label halign={Gtk.Align.START} label="Governor" />
        <label
          hexpand
          halign={Gtk.Align.END}
          label={status((s) => `${s.governor} · ${eppLabel(s.epp)}`)}
        />
      </box>

      {/* CPU Temperature */}
      <box class="setting" hexpand spacing={5}>
        <label halign={Gtk.Align.START} label="CPU Temperature" />
        <box hexpand halign={Gtk.Align.END} spacing={5}>
          <levelbar
            widthRequest={150}
            minValue={0}
            maxValue={100}
            value={status((s) => s.cpuTemp)}
          />
          <label
            css={status((s) => {
              if (s.cpuTemp >= 90) return "color: #ff5555;";
              if (s.cpuTemp >= 80) return "color: #ffb86c;";
              if (s.cpuTemp >= 70) return "color: #f1fa8c;";
              return "color: #50fa7b;";
            })}
            label={status((s) => `${s.cpuTemp}°C`)}
          />
        </box>
      </box>

      {/* CPU Frequency */}
      <box class="setting" hexpand spacing={5}>
        <label halign={Gtk.Align.START} label="CPU Frequency" />
        <box hexpand halign={Gtk.Align.END} spacing={5}>
          <levelbar
            widthRequest={150}
            minValue={400}
            maxValue={status((s) => s.maxFreq || 4500)}
            value={status((s) => s.curFreq)}
          />
          <label
            css="color: #8be9fd;"
            label={status((s) => s.curFreq >= 1000
              ? `${(s.curFreq / 1000).toFixed(1)} GHz`
              : `${s.curFreq} MHz`
            )}
          />
        </box>
      </box>

      {/* Power Source + Turbo */}
      <box class="setting" hexpand spacing={5}>
        <label halign={Gtk.Align.START} label="Power Source" />
        <label
          hexpand
          halign={Gtk.Align.END}
          label={status((s) => {
            const source = s.acOnline ? "⚡ AC" : "🔋 Battery";
            const turbo = s.boost ? " · Turbo On" : " · Turbo Off";
            return source + turbo;
          })}
        />
      </box>
    </box>
  );
};

// Thermal Limit Slider
const ThermalLimitSlider = () => {
  return (
    <box class="setting" hexpand spacing={5}>
      <label halign={Gtk.Align.START} label="Thermal Limit" />
      <box hexpand halign={Gtk.Align.END} spacing={5}>
        <slider
          widthRequest={150}
          drawValue={false}
          min={70}
          max={100}
          value={thermalLimit()}
          onValueChanged={(self) => {
            const value = Math.round(self.get_value());
            setThermalLimit(value);
            currentThermalLimit = value;
          }}
        />
        <label label={thermalLimit((t) => `${t}°C`)} widthRequest={50} />
      </box>
    </box>
  );
};

// Action Buttons
const ActionButtons = () => {
  return (
    <box halign={Gtk.Align.END} spacing={8}>
      <button
        class="widget"
        label="Refresh"
        tooltipMarkup="<b>Refresh system info</b>"
        onClicked={() => refreshStatus()}
      />
      <button
        class="widget"
        label="Apply Thermal"
        tooltipMarkup="<b>Apply thermal limit via RyzenAdj</b>"
        onClicked={() => applyThermalLimit(currentThermalLimit)}
      />
    </box>
  );
};

// zen-cpufreq daemon status label
const DaemonStatus = () => {
  return (
    <box class="setting" hexpand spacing={5}>
      <label
        halign={Gtk.Align.START}
        class="dim"
        label={status((s) => "zen-cpufreq: " + (s.mode === "inactive" ? "stopped" : "running (" + s.mode + ")"))}
      />
    </box>
  );
};

// Main Power Widget
export const PowerWidget = () => {
  return (
    <box
      class={"category"}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={16}
      $={() => {
        timeout(1000, async () => {
          await refreshStatus();
          initialized = true;
        });
      }}
    >
      <label label="Power" halign={Gtk.Align.START} />
      <ModeSelector />
      <SystemInfo />
      <ThermalLimitSlider />
      <ActionButtons />
      <DaemonStatus />
    </box>
  );
};

export default PowerWidget;
