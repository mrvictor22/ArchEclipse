import Gtk from "gi://Gtk?version=4.0";
import { createState } from "ags";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import { notify } from "../../../utils/notification";

// Platform profiles (Linux kernel ACPI)
const platformProfiles = [
  { id: "performance", name: "Performance", icon: "⚡" },
  { id: "balanced", name: "Balanced", icon: "⚖️" },
  { id: "low-power", name: "Power Saver", icon: "🔋" },
];

// State
const [currentProfile, setCurrentProfile] = createState<string>("balanced");
const [cpuTemp, setCpuTemp] = createState<number>(0);
const [cpuFreq, setCpuFreq] = createState<number>(0);
const [thermalLimit, setThermalLimit] = createState<number>(90);
const [isOnAC, setIsOnAC] = createState<boolean>(true);
const [hasPlatformProfile, setHasPlatformProfile] = createState<boolean>(false);

// Store current thermal limit for apply button
let currentThermalLimit = 90;

// Check if platform_profile is available
const checkPlatformProfile = async () => {
  try {
    await execAsync("bash -c 'test -f /sys/firmware/acpi/platform_profile'");
    setHasPlatformProfile(true);
    // Read current profile
    const profile = await execAsync("cat /sys/firmware/acpi/platform_profile");
    setCurrentProfile(profile.trim());
  } catch {
    setHasPlatformProfile(false);
  }
};

// Refresh system info
const refreshSystemInfo = async () => {
  try {
    const tempResult = await execAsync(
      "bash -c 'cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1'"
    );
    const temp = parseInt(tempResult.trim()) / 1000;
    if (!isNaN(temp) && temp > 0) setCpuTemp(Math.round(temp));
  } catch { /* ignore */ }

  try {
    const freqResult = await execAsync(
      "bash -c 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq'"
    );
    const freq = parseInt(freqResult.trim()) / 1000;
    if (!isNaN(freq) && freq > 0) setCpuFreq(Math.round(freq));
  } catch { /* ignore */ }

  try {
    const acResult = await execAsync(
      "bash -c 'cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1'"
    );
    setIsOnAC(acResult.trim() === "1");
  } catch { /* ignore */ }

  try {
    const profile = await execAsync("cat /sys/firmware/acpi/platform_profile");
    setCurrentProfile(profile.trim());
  } catch { /* ignore */ }
};

// Set platform profile (uses pkexec for root)
const setPlatformProfile = async (profile: string) => {
  try {
    await execAsync(
      `pkexec bash -c 'echo ${profile} > /sys/firmware/acpi/platform_profile'`
    );
    setCurrentProfile(profile);
    notify({
      summary: "Power Profile",
      body: `Changed to ${profile}`,
    });
    refreshSystemInfo();
  } catch (e) {
    notify({
      summary: "Profile Error",
      body: `${e}`,
    });
  }
};

// Apply thermal limit via RyzenAdj
const applyThermalLimit = async (tctlTemp: number) => {
  try {
    const output = await execAsync(
      `pkexec ryzenadj --tctl-temp=${tctlTemp}`
    );
    notify({
      summary: "Thermal Limit",
      body: output.trim() || `Set to ${tctlTemp}°C`,
    });
    return true;
  } catch (e) {
    notify({
      summary: "RyzenAdj Error",
      body: `${e}`,
    });
    return false;
  }
};

// Initialize on first render (not at module load to avoid Gjs_App error)

// Profile Selector Component
const ProfileSelector = () => {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <label
        class={"subcategory-label"}
        label={"Platform Profile"}
        halign={Gtk.Align.START}
      />
      <box class="setting" spacing={10} hexpand>
        {platformProfiles.map((profile) => (
          <togglebutton
            hexpand
            class="widget"
            label={profile.id}
            tooltipMarkup={`<b>${profile.name}</b> ${profile.icon}`}
            active={currentProfile((p) => p === profile.id)}
            onToggled={({ active }) => {
              if (active && currentProfile.peek() !== profile.id) {
                setPlatformProfile(profile.id);
              }
            }}
          />
        ))}
      </box>
    </box>
  );
};

// Temperature Display
const TempDisplay = () => {
  return (
    <box class="setting" hexpand spacing={5}>
      <label halign={Gtk.Align.START} label="CPU Temperature" />
      <box hexpand halign={Gtk.Align.END} spacing={5}>
        <levelbar
          widthRequest={150}
          minValue={0}
          maxValue={100}
          value={cpuTemp()}
        />
        <label
          css={cpuTemp((t) => {
            if (t >= 90) return "color: #ff5555;";
            if (t >= 80) return "color: #ffb86c;";
            if (t >= 70) return "color: #f1fa8c;";
            return "color: #50fa7b;";
          })}
          label={cpuTemp((t) => `${t}°C`)}
        />
      </box>
    </box>
  );
};

// CPU Frequency Display
const FreqDisplay = () => {
  return (
    <box class="setting" hexpand spacing={5}>
      <label halign={Gtk.Align.START} label="CPU Frequency" />
      <box hexpand halign={Gtk.Align.END} spacing={5}>
        <levelbar
          widthRequest={150}
          minValue={400}
          maxValue={4500}
          value={cpuFreq()}
        />
        <label
          css="color: #8be9fd;"
          label={cpuFreq((f) => f >= 1000 ? `${(f/1000).toFixed(1)} GHz` : `${f} MHz`)}
        />
      </box>
    </box>
  );
};

// Power Status
const PowerStatus = () => {
  return (
    <box class="setting" hexpand spacing={5}>
      <label halign={Gtk.Align.START} label="Power Source" />
      <box hexpand halign={Gtk.Align.END} spacing={5}>
        <label label={isOnAC((ac) => ac ? "⚡ AC Power" : "🔋 Battery")} />
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
        onClicked={() => refreshSystemInfo()}
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

// Main Power Widget
export const PowerWidget = () => {
  return (
    <box
      class={"category"}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={16}
      $={() => {
        // Delay init to avoid gnim reconciliation bug with <This this={app}> in app.tsx
        timeout(2000, () => {
          checkPlatformProfile();
          refreshSystemInfo();
        });
      }}
    >
      <label label="Power" halign={Gtk.Align.START} />
      <ProfileSelector />
      <TempDisplay />
      <FreqDisplay />
      <PowerStatus />
      <ThermalLimitSlider />
      <ActionButtons />
    </box>
  );
};

export default PowerWidget;
