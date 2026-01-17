import { createState, createComputed, For } from "ags";
import { exec, execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { notify } from "../utils/notification";
import { focusedWorkspace, globalTransition } from "../variables";
import { getMonitorName } from "../utils/monitor";
import Picture from "./Picture";
import Gio from "gi://Gio";
import GLib from "gi://GLib?version=2.0";
import { Progress } from "./Progress";
import { timeout } from "ags/time";
import { Gdk } from "ags/gtk4";
import GObject from "gnim/gobject";

// progress status
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

// State management
const [selectedWorkspaceId, setSelectedWorkspaceId] = createState<number>(0);
const [selectedWorkspaceWidget, setSelectedWorkspaceWidget] =
  createState<Gtk.Widget>(null!);

// Store wallpaper paths for current workspaces PER MONITOR
const [workspaceWallpapersByMonitor, setWorkspaceWallpapersByMonitor] = createState<Map<string, string[]>>(new Map());

// Helper to update wallpapers for a specific monitor
const setMonitorWallpapers = (monitorName: string, wallpapers: string[]) => {
  const newMap = new Map(workspaceWallpapersByMonitor.peek());
  newMap.set(monitorName, wallpapers);
  setWorkspaceWallpapersByMonitor(newMap);
};

// Helper to get wallpapers for a specific monitor
const getMonitorWallpapers = (monitorName: string): string[] => {
  return workspaceWallpapersByMonitor.peek().get(monitorName) || [];
};

const updateSelectedWorkspaceWidget = (
  workspaceId: number,
  widget: Gtk.Widget
) => {
  setSelectedWorkspaceId(workspaceId);
  setSelectedWorkspaceWidget(widget);
};

const targetTypes = ["workspace", "sddm", "lockscreen"];
const [targetType, setTargetType] = createState<string>("workspace");

const [allWallpapers, setAllWallpapers] = createState<string[]>([]);

const FetchWallpapers = async () => {
  try {
    await execAsync("bash ./scripts/wallpaper-to-thumbnail.sh");

    const [defaultWalls, customWalls, discretionWalls] = await Promise.all([
      execAsync("bash ./scripts/get-wallpapers.sh --defaults").then(JSON.parse),
      execAsync("bash ./scripts/get-wallpapers.sh --custom").then(JSON.parse),
      execAsync("bash ./scripts/get-wallpapers.sh --discretion").then(JSON.parse).catch(() => []),
    ]);

    const category = wallpaperCategory.peek();
    switch (category) {
      case "defaults":
        setAllWallpapers(defaultWalls);
        break;
      case "custom":
        setAllWallpapers(customWalls);
        break;
      case "discretion":
        setAllWallpapers(discretionWalls);
        break;
      default:
        setAllWallpapers([...defaultWalls, ...customWalls]);
    }
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    print("Error fetching wallpapers: " + String(err));
  }
};

// Wallpaper category filter
type WallpaperCategory = "all" | "defaults" | "custom" | "discretion";
const [wallpaperCategory, setWallpaperCategory] = createState<WallpaperCategory>("all");

const categoryLabels: Record<WallpaperCategory, string> = {
  all: "All",
  defaults: "Defaults",
  custom: "Custom",
  discretion: "SFW",
};

// Discretion mode state
const [discretionMode, setDiscretionMode] = createState<boolean>(false);

const checkDiscretionMode = () => {
  try {
    const result = exec("bash -c '$HOME/.config/hypr/scripts/discretion-mode.sh status 2>/dev/null | head -1'");
    // Check for ": on" specifically to avoid matching "Discretion" which contains "on"
    return result.includes(": on");
  } catch {
    return false;
  }
};

// Refresh workspace thumbnails for all monitors
const refreshAllWorkspaceThumbnails = () => {
  try {
    const monitors = JSON.parse(exec("hyprctl monitors -j"));
    for (const monitor of monitors) {
      const monitorName = monitor.name;
      const wallpapers = getCurrentWorkspaceWallpapers(monitorName);
      setMonitorWallpapers(monitorName, wallpapers);
    }
  } catch (err) {
    print("Error refreshing workspace thumbnails: " + String(err));
  }
};

const toggleDiscretionMode = async () => {
  setProgressStatus("loading");
  try {
    await execAsync("bash -c '$HOME/.config/hypr/scripts/discretion-mode.sh toggle'");
    const newState = checkDiscretionMode();
    setDiscretionMode(newState);
    // Refresh workspace thumbnails after mode change
    refreshAllWorkspaceThumbnails();
    setProgressStatus("success");
  } catch (err) {
    setProgressStatus("error");
    notify({ summary: "Error", body: String(err) });
  }
};

export function toThumbnailPath(file: string) {
  return file.replace(
    "/.config/wallpapers/",
    "/.config/ags/assets/thumbnails/"
  );
}

// Get wallpaper paths for current monitor (not widgets)
const getCurrentWorkspaceWallpapers = (monitorName: string): string[] => {
  const wallpapers: string[] = JSON.parse(
    exec(`bash ./scripts/get-wallpapers.sh --current ${monitorName}`) || "[]"
  );
  return wallpapers;
};

// Create workspace button component (created fresh each render)
function WorkspaceButton({ wallpaper, workspaceId }: { wallpaper: string; workspaceId: number }) {
  return (
    <button
      class={focusedWorkspace((workspace) => {
        const i = workspace?.id || 1;
        return i === workspaceId
          ? "wallpaper-button focused"
          : "wallpaper-button";
      })}
      onClicked={(self) => {
        setTargetType("workspace");
        updateSelectedWorkspaceWidget(workspaceId, self);
      }}
      $={(self) => {
        const i = focusedWorkspace.get()?.id || 1;
        if (i === workspaceId) {
          updateSelectedWorkspaceWidget(workspaceId, self);
        }
      }}
      tooltipMarkup={`Set wallpaper for <b>Workspace ${workspaceId}</b>`}
    >
      <Picture class="wallpaper" file={toThumbnailPath(wallpaper)}></Picture>
    </button>
  ) as Gtk.Button;
}

// Main Display Component
function Display({ monitorName }: { monitorName: string }) {
  const allWallpapersDisplay = (
    <Gtk.ScrolledWindow
      hscrollbarPolicy={Gtk.PolicyType.ALWAYS}
      vscrollbarPolicy={Gtk.PolicyType.NEVER}
      hexpand
      vexpand
    >
      <Gtk.Box class="all-wallpapers" spacing={5}>
        <For each={allWallpapers}>
          {(wallpaper, key) => {
            const handleLeftClick = (self: Gtk.Button) => {
              setProgressStatus("loading");
              const target = targetType.peek();
              const command = {
                sddm: `pkexec sh -c 'sed -i "s|^background=.*|background=\"${wallpaper}\"|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                lockscreen: `bash -c "cp '${wallpaper}' $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                workspace: `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
                  (self.get_root() as any).monitorName
                } '${wallpaper}'"`,
              }[target];

              execAsync(command!)
                .then(() => {
                  const picture = (
                    selectedWorkspaceWidget.peek() as any
                  ).child.getPicture() as Gtk.Picture;
                  if (target === "workspace" && picture) {
                    picture.file = Gio.File.new_for_path(wallpaper);
                  }
                })
                .finally(() => {
                  setProgressStatus("success");
                })
                .catch((err) => {
                  setProgressStatus("error");
                  notify({ summary: "Error", body: String(err) });
                  throw err;
                });
            };

            const handleRightClick = () => {
              setProgressStatus("loading");
              execAsync(
                `bash -c "rm -f '${toThumbnailPath(
                  wallpaper
                )}' && rm -f '${wallpaper}'"`
              )
                .then(() =>
                  notify({
                    summary: "Success",
                    body: "Wallpaper deleted successfully!",
                  })
                )
                .catch((err) => {
                  setProgressStatus("error");
                  notify({ summary: "Error", body: String(err) });
                  throw err;
                })
                .finally(() => {
                  FetchWallpapers();
                  setProgressStatus("success");
                });
            };

            return (
              <button
                class="wallpaper-button preview"
                onClicked={handleLeftClick}
                $={(self) => {
                  const gesture = new Gtk.GestureClick({
                    button: 3, // Right click only
                  });

                  gesture.connect("pressed", () => {
                    handleRightClick();
                  });

                  self.add_controller(gesture);
                }}
                tooltipMarkup={targetType(
                  (type) =>
                    "Click to set as <b>" +
                    type +
                    "</b> wallpaper.\nRight-click to delete."
                )}
              >
                <Picture
                  class="wallpaper"
                  file={toThumbnailPath(wallpaper)}
                ></Picture>
              </button>
            );
          }}
        </For>
      </Gtk.Box>
    </Gtk.ScrolledWindow>
  );

  const resetButton = (
    <button
      valign={Gtk.Align.CENTER}
      class="reload-wallpapers"
      label="󰑐"
      tooltipMarkup={`Reload <b>HyprPaper</b>`}
      onClicked={() => {
        execAsync('bash -c "$HOME/.config/hypr/hyprpaper/reload.sh"')
          .finally(FetchWallpapers)
          .catch(notify);
      }}
    />
  );

  const randomButton = (
    <button
      valign={Gtk.Align.CENTER}
      class="random-wallpaper"
      label=""
      tooltipMarkup={`Set a <b>Random</b> wallpaper`}
      onClicked={(self) => {
        setProgressStatus("loading");
        const randomWallpaper =
          allWallpapers.peek()[
            Math.floor(Math.random() * allWallpapers.peek().length)
          ];
        execAsync(
          `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
            (self.get_root() as any).monitorName
          } '${randomWallpaper}'"`
        )
          .finally(() => {
            const newWallpaper = JSON.parse(
              exec(
                `bash ./scripts/get-wallpapers.sh --current ${
                  (self.get_root() as any).monitorName
                }`
              )
            )[selectedWorkspaceId.peek() - 1];
            const picture = (
              selectedWorkspaceWidget.peek() as any
            ).child.getPicture() as Gtk.Picture;
            if (picture) {
              picture.file = Gio.File.new_for_path(newWallpaper);
            }
            setProgressStatus("success");
          })
          .catch((err) => {
            setProgressStatus("error");
            notify({ summary: "Error", body: String(err) });
          });
      }}
    />
  );

  const categoryButtons = (
    <box class="categories" halign={Gtk.Align.CENTER}>
      {(["all", "defaults", "custom", "discretion"] as WallpaperCategory[]).map((cat) => (
        <togglebutton
          valign={Gtk.Align.CENTER}
          class={`category-${cat}`}
          label={categoryLabels[cat]}
          active={wallpaperCategory((c) => c === cat)}
          onToggled={({ active }) => {
            if (active) {
              setWallpaperCategory(cat);
              FetchWallpapers();
            }
          }}
        />
      ))}
    </box>
  );

  const randomAllButton = (
    <button
      valign={Gtk.Align.CENTER}
      class="random-all"
      label="󰒝"
      tooltipMarkup={wallpaperCategory((cat) =>
        `<b>Random All Workspaces</b>\nApply random wallpapers from <b>${categoryLabels[cat]}</b> to all workspaces`
      )}
      onClicked={async (self) => {
        setProgressStatus("loading");
        const monitorName = (self.get_root() as any).monitorName;
        const category = wallpaperCategory.peek();

        try {
          // Use dedicated script for efficiency (single process, no zombies)
          await execAsync(
            `bash -c "$HOME/.config/hypr/scripts/random-all-wallpapers.sh '${monitorName}' '${category}'"`
          );

          // Refresh workspace thumbnails
          setMonitorWallpapers(monitorName, getCurrentWorkspaceWallpapers(monitorName));

          notify({ summary: "Success", body: "Random wallpapers applied to all workspaces!" });
          setProgressStatus("success");
        } catch (err) {
          setProgressStatus("error");
          notify({ summary: "Error", body: String(err) });
        }
      }}
    />
  );

  const targetButtons = (
    <box class="targets" hexpand={true} halign={Gtk.Align.CENTER}>
      {targetTypes.map((type) => (
        <togglebutton
          valign={Gtk.Align.CENTER}
          class={type}
          label={type}
          active={targetType((t) => t === type)}
          onToggled={({ active }) => {
            if (active) setTargetType(type);
          }}
        />
      ))}
    </box>
  );

  const selectedWorkspaceLabel = (
    <label
      class="selected-workspace"
      label={createComputed(
        () =>
          `Wallpaper -> ${targetType()} ${
            targetType() === "workspace" ? selectedWorkspaceId() : ""
          }`
      )}
      $={(self) =>
        createComputed([selectedWorkspaceId, targetType]).subscribe(() => {
          self.add_css_class("ping");
          timeout(500, () => {
            self.remove_css_class("ping");
          });
        })
      }
    />
  );

  const addWallpaper = (
    <button
      label=""
      class="upload"
      tooltipMarkup={`Add a <b>New Custom Wallpaper</b>`}
      onClicked={async (self) => {
        setProgressStatus("loading");
        const dialog = new Gtk.FileDialog({
          title: "Open Image",
          modal: true,
        });

        // Image filter
        const filter = new Gtk.FileFilter();
        filter.set_name("Images");
        filter.add_mime_type("image/png");
        filter.add_mime_type("image/jpeg");
        filter.add_mime_type("image/webp");
        filter.add_mime_type("image/gif");

        dialog.set_default_filter(filter);

        try {
          const root = self.get_root();
          if (!(root instanceof Gtk.Window)) return;

          const file: Gio.File = await new Promise((resolve, reject) => {
            dialog.open(root, null, (dlg, res) => {
              try {
                resolve(dlg!.open_finish(res));
              } catch (e) {
                reject(e);
              }
            });
          });

          if (!file) return;

          const filename = file.get_path();
          if (!filename) return;

          await execAsync(
            `bash -c "cp '${filename}' $HOME/.config/wallpapers/custom"`
          );

          notify({
            summary: "Success",
            body: "Wallpaper added successfully!",
          });
          setProgressStatus("success");

          // FetchWallpapers();
        } catch (err) {
          // Gtk.FileDialog throws on cancel — ignore silently
          if (
            err instanceof GLib.Error &&
            err.matches(Gtk.dialog_error_quark(), Gtk.DialogError.CANCELLED)
          )
            return;

          setProgressStatus("error");

          notify({
            summary: "Error",
            body: String(err),
          });
        }
      }}
    />
  );

  const discretionToggle = (
    <togglebutton
      valign={Gtk.Align.CENTER}
      class="discretion-mode"
      label={discretionMode((mode) => (mode ? "󰈈" : "󰈈"))}
      active={discretionMode()}
      tooltipMarkup={discretionMode((mode) =>
        mode
          ? "<b>Discretion Mode ON</b>\nClick to show normal wallpapers"
          : "<b>Discretion Mode OFF</b>\nClick to enable SFW wallpapers"
      )}
      onToggled={() => toggleDiscretionMode()}
      $={() => setDiscretionMode(checkDiscretionMode())}
    />
  );

  const actions = (
    <box class="actions" hexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
      {targetButtons}
      {selectedWorkspaceLabel}
      {categoryButtons}
      {discretionToggle}
      {randomButton}
      {randomAllButton}
      {resetButton}
      {addWallpaper}
      <Progress
        status={progressStatus}
        transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
      />
    </box>
  );

  return (
    <box
      class="wallpaper-switcher"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={20}
    >
      <box hexpand={true} vexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
        <For each={workspaceWallpapersByMonitor((map) => map.get(monitorName) || [])}>
          {(wallpaper, index) => (
            <WorkspaceButton wallpaper={wallpaper} workspaceId={index + 1} />
          )}
        </For>
      </box>
      {actions}
      {allWallpapersDisplay}
    </box>
  );
}

export default ({ monitor }: { monitor: Gdk.Monitor }) => {
  const monitorName = getMonitorName(monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      namespace="wallpaper-switcher"
      name={`wallpaper-switcher-${monitorName}`}
      application={app}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.RIGHT
      }
      $={async (self) => {
        (self as any).monitorName = monitorName;
        FetchWallpapers();
        setMonitorWallpapers(monitorName, getCurrentWorkspaceWallpapers(monitorName));
        focusedWorkspace.subscribe(() => {
          const workspace = focusedWorkspace.peek();
          if (workspace) {
            setSelectedWorkspaceId(workspace.id);
          }
        });
      }}
    >
      <Display monitorName={monitorName} />
    </window>
  );
};

monitorFile("./../wallpapers/custom", async () => FetchWallpapers());
