import { createState } from "ags";
import GLib from "gi://GLib?version=2.0";
import Gtk from "gi://Gtk?version=4.0";
import { globalTransition } from "../variables";

// Use pulse instead of pipewire due to pipewire capture bug
// See: https://github.com/karlstav/cava/issues/689
const CAVA_DISABLED = false;
const CAVA_INPUT_PULSE = 4; // AstalCavaInput.PULSE

// Import AstalCava with version - same pattern as other gi imports
let Cava: any = null;
let cavaInstance: any = null;
let cavaAvailable = false;

// Only try to import if not disabled
if (!CAVA_DISABLED) {
  try {
    const AstalCava = (imports.gi.versions.AstalCava = "0.1", imports.gi.AstalCava);
    Cava = AstalCava;
    cavaAvailable = true;
  } catch (e) {
    print("AstalCava module not available:", e);
    cavaAvailable = false;
  }
}

function getCavaInstance(): any {
  if (!cavaAvailable || !Cava) return null;

  if (!cavaInstance) {
    try {
      cavaInstance = Cava.Cava.get_default();
    } catch (e) {
      print("Failed to get Cava instance:", e);
      return null;
    }
  }
  return cavaInstance;
}

// --- Tunable constants ---
const CAVA_UPDATE_MS = 60;

function scheduleCoalesced(fn: () => void, delayMs: number) {
  let pending = false;
  return () => {
    if (pending) return;
    pending = true;
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
      pending = false;
      try {
        fn();
      } catch (e) {
        console.error("Cava update error:", e);
      }
      return GLib.SOURCE_REMOVE;
    });
  };
}

export default ({
  transitionType,
  barCount = 12,
}: {
  transitionType: Gtk.RevealerTransitionType;
  barCount?: number;
}) => {
  // Get cava instance (lazy initialization)
  const cava = getCavaInstance();

  if (!cava) {
    print("Cava not available, returning empty widget");
    return (
      <revealer revealChild={false} transitionDuration={globalTransition} transitionType={transitionType}>
        <label class="cava" label="" />
      </revealer>
    );
  }

  // Configure cava: use pulse input (pipewire has capture bug) and set bars
  try {
    cava.set_input(CAVA_INPUT_PULSE);
    cava.set_bars(barCount);
  } catch (e) {
    print("Failed to configure cava:", e);
  }

  const [getBars, setBars] = createState("");

  const BLOCKS = ["\u2581", "\u2582", "\u2583", "\u2584", "\u2585", "\u2586", "\u2587", "\u2588"];
  const BLOCKS_LENGTH = BLOCKS.length;
  const EMPTY_BARS = "".padEnd(barCount, "\u2581");

  let barArray: string[] = new Array(barCount);
  let lastBarString = "";
  let visible = false;
  let showTimeoutId: number | null = null;
  let hideTimeoutId: number | null = null;
  let revealerInstance: Gtk.Revealer | null = null;

  const REVEAL_SHOW_DELAY = 300;
  const REVEAL_HIDE_DELAY = 700;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={transitionType}
      $={(self) => (revealerInstance = self)}
    >
      <label
        class="cava"
        onDestroy={() => {
          if (showTimeoutId) { try { GLib.source_remove(showTimeoutId); } catch {} }
          if (hideTimeoutId) { try { GLib.source_remove(hideTimeoutId); } catch {} }
        }}
        label={getBars}
      />
    </revealer>
  );

  let lastValuesCache: number[] | null = null;

  const doUpdate = () => {
    const values = lastValuesCache;

    if (!values || values.length === 0) {
      for (let j = 0; j < barCount; j++) barArray[j] = BLOCKS[0];
    } else {
      if (barArray.length !== values.length) barArray = new Array(values.length);
      for (let i = 0; i < values.length && i < barCount; i++) {
        const idx = Math.min(Math.floor(values[i] * BLOCKS_LENGTH), BLOCKS_LENGTH - 1);
        barArray[i] = BLOCKS[idx];
      }
      for (let j = values.length; j < barCount; j++) barArray[j] = BLOCKS[0];
    }

    const b = barArray.join("");
    if (b === lastBarString) return;
    lastBarString = b;
    setBars(b);

    const isEmpty = b === EMPTY_BARS;

    if (!isEmpty) {
      if (hideTimeoutId) { try { GLib.source_remove(hideTimeoutId); } catch {} hideTimeoutId = null; }
      if (!visible && !showTimeoutId) {
        showTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, REVEAL_SHOW_DELAY, () => {
          visible = true;
          if (revealerInstance) revealerInstance.reveal_child = true;
          showTimeoutId = null;
          return GLib.SOURCE_REMOVE;
        });
      } else if (visible && revealerInstance) {
        revealerInstance.reveal_child = true;
      }
    } else {
      if (showTimeoutId) { try { GLib.source_remove(showTimeoutId); } catch {} showTimeoutId = null; }
      if (visible && !hideTimeoutId) {
        hideTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, REVEAL_HIDE_DELAY, () => {
          visible = false;
          if (revealerInstance) revealerInstance.reveal_child = false;
          hideTimeoutId = null;
          return GLib.SOURCE_REMOVE;
        });
      } else if (!visible && revealerInstance) {
        revealerInstance.reveal_child = false;
      }
    }
  };

  const schedule = scheduleCoalesced(doUpdate, CAVA_UPDATE_MS);

  // Connect to cava signal with delay to avoid race condition
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
    try {
      if (cava) {
        cava.connect("notify::values", () => {
          try {
            lastValuesCache = cava.get_values() || null;
            schedule();
          } catch (e) {
            // Silently ignore errors
          }
        });
      }
    } catch (e) {
      print("Failed to connect cava signal:", e);
    }
    return GLib.SOURCE_REMOVE;
  });

  return revealer;
};
