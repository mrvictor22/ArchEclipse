import { execAsync } from "ags/process";
import GLib from "gi://GLib?version=2.0";
import Gtk from "gi://Gtk?version=4.0";
import Pango from "gi://Pango";
import Notifd from "gi://AstalNotifd";
import { globalTransition, NOTIFICATION_DELAY } from "../../../variables";
import { notify } from "../../../utils/notification";
import { time } from "../../../utils/time";

const TRANSITION = 200;

function NotificationIcon(n: Notifd.Notification): Gtk.Widget {
  const notificationIcon = n.image || n.app_icon || n.desktopEntry;

  if (!notificationIcon) {
    return new Gtk.Image({
      icon_name: "dialog-information-symbolic",
      css_classes: ["icon"],
    });
  }

  const box = new Gtk.Box({
    css_classes: ["image"],
  });
  // Use inline CSS for background image
  const cssProvider = new Gtk.CssProvider();
  cssProvider.load_from_string(`
    .notification-image-${n.id} {
      background-image: url("${notificationIcon}");
      background-size: cover;
      background-repeat: no-repeat;
      background-position: center;
      border-radius: 10px;
      min-width: 48px;
      min-height: 48px;
    }
  `);
  box.get_style_context().add_provider(cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
  box.add_css_class(`notification-image-${n.id}`);
  return box;
}

function copyNotificationContent(n: Notifd.Notification) {
  if (n.appIcon) {
    execAsync(`bash -c "wl-copy --type image/png < '${n.appIcon}'"`)
      .finally(() => notify({ summary: "Copied", body: n.appIcon }))
      .catch((err) => notify({ summary: "Error", body: String(err) }));
    return;
  }

  const content = n.body || n.app_name;
  if (!content) return;
  execAsync(`wl-copy "${content}"`).catch((err) =>
    notify({ summary: "Error", body: String(err) })
  );
}

export default ({
  n,
  newNotification = false,
  popup = false,
}: {
  n: Notifd.Notification;
  newNotification?: boolean;
  popup?: boolean;
}): Gtk.Widget => {
  // Use simple boolean instead of createState to avoid tracking context issues
  let isLocked = false;

  // Create revealer reference for closeNotification
  let mainRevealer: Gtk.Revealer;

  function closeNotification(dismiss = false) {
    if (mainRevealer) {
      mainRevealer.reveal_child = false;
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, globalTransition, () => {
        if (dismiss) n.dismiss();
        return false;
      });
    }
  }

  // Create all widgets imperatively to avoid GTK4 parent issues
  const iconBox = new Gtk.Box({
    valign: Gtk.Align.START,
    halign: Gtk.Align.CENTER,
    hexpand: false,
    css_classes: ["icon"],
  });
  iconBox.append(NotificationIcon(n));

  const titleLabel = new Gtk.Label({
    css_classes: ["title"],
    xalign: 0,
    justify: Gtk.Justification.LEFT,
    hexpand: true,
    max_width_chars: 24,
    wrap: true,
    label: n.summary || "",
    use_markup: true,
    ellipsize: Pango.EllipsizeMode.END,
  });

  const bodyLabel = new Gtk.Label({
    css_classes: ["body"],
    hexpand: true,
    max_width_chars: 24,
    xalign: 0,
    justify: Gtk.Justification.LEFT,
    label: n.body || "",
    wrap: true,
    ellipsize: Pango.EllipsizeMode.END,
  });

  // Expand toggle button
  const expandButton = new Gtk.ToggleButton({
    css_classes: ["expand"],
    active: false,
    label: "",
  });
  expandButton.connect("toggled", () => {
    // GTK4: use ellipsize property
    titleLabel.ellipsize = expandButton.active ? Pango.EllipsizeMode.NONE : Pango.EllipsizeMode.END;
    bodyLabel.ellipsize = expandButton.active ? Pango.EllipsizeMode.NONE : Pango.EllipsizeMode.END;
    expandButton.label = expandButton.active ? "" : "";
  });

  const expandRevealer = new Gtk.Revealer({
    reveal_child: false,
    transition_type: Gtk.RevealerTransitionType.CROSSFADE,
    transition_duration: globalTransition,
    child: expandButton,
  });

  // Lock button (for popup mode)
  const lockButton = new Gtk.ToggleButton({
    css_classes: ["lock"],
    label: "",
  });
  lockButton.connect("toggled", () => {
    isLocked = lockButton.active;
  });

  // Copy button (for history mode)
  const copyButton = new Gtk.Button({
    css_classes: ["copy"],
    label: "",
  });
  copyButton.connect("clicked", () => copyNotificationContent(n));

  const leftRevealer = new Gtk.Revealer({
    reveal_child: false,
    transition_type: Gtk.RevealerTransitionType.CROSSFADE,
    transition_duration: globalTransition,
    child: popup ? lockButton : copyButton,
  });

  // Close button
  const closeButton = new Gtk.Button({
    css_classes: ["close"],
    label: "",
  });
  closeButton.connect("clicked", () => closeNotification(true));

  const closeRevealer = new Gtk.Revealer({
    reveal_child: false,
    transition_type: Gtk.RevealerTransitionType.CROSSFADE,
    transition_duration: globalTransition,
    child: closeButton,
  });

  // Top bar
  const appNameLabel = new Gtk.Label({
    css_classes: ["app-name"],
    xalign: 0,
    wrap: true,
    label: n.app_name || "",
  });

  const timeLabel = new Gtk.Label({
    css_classes: ["time"],
    xalign: 1,
    label: time(n.time),
  });

  const progressBox = new Gtk.Box({
    visible: popup,
    css_classes: ["circular-progress-box"],
  });

  const leftBox = new Gtk.Box({ spacing: 5, hexpand: true });
  leftBox.append(progressBox);
  leftBox.append(appNameLabel);
  leftBox.append(leftRevealer);

  const quickActionsBox = new Gtk.Box({ css_classes: ["quick-actions"] });
  quickActionsBox.append(closeRevealer);
  quickActionsBox.append(expandRevealer);

  const topBar = new Gtk.Box({
    css_classes: ["top-bar"],
    hexpand: true,
    spacing: 5,
  });
  topBar.append(leftBox);
  topBar.append(quickActionsBox);
  topBar.append(timeLabel);

  // Content layout
  const textBox = new Gtk.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 5,
  });
  const titleBox = new Gtk.Box({ hexpand: true });
  titleBox.append(titleLabel);
  textBox.append(titleBox);
  textBox.append(bodyLabel);

  const contentRow = new Gtk.Box({ spacing: 5 });
  contentRow.append(iconBox);
  contentRow.append(textBox);

  const mainContent = new Gtk.Box({
    css_classes: ["main-content"],
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 10,
  });
  mainContent.append(topBar);
  mainContent.append(contentRow);

  // Build urgency class safely
  const urgencyClass = n.urgency !== undefined ? String(n.urgency) : "";
  const appClass = n.app_name || "";
  const notificationBox = new Gtk.Box({
    css_classes: ["notification", urgencyClass, appClass].filter(Boolean),
  });
  notificationBox.append(mainContent);

  // Main revealer
  mainRevealer = new Gtk.Revealer({
    transition_type: Gtk.RevealerTransitionType.SWING_DOWN,
    transition_duration: TRANSITION,
    reveal_child: !newNotification,
    child: notificationBox,
  });

  // Animate reveal after creation
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1, () => {
    if (mainRevealer) mainRevealer.reveal_child = true;
    return false;
  });

  // Event box for hover/click
  const eventBox = new Gtk.Box({
    css_classes: ["notification-eventbox"],
    visible: true,
  });

  // Add hover controller
  const motionController = new Gtk.EventControllerMotion();
  motionController.connect("enter", () => {
    leftRevealer.reveal_child = true;
    closeRevealer.reveal_child = true;
    expandRevealer.reveal_child = true;
  });
  motionController.connect("leave", () => {
    if (!isLocked) leftRevealer.reveal_child = false;
    closeRevealer.reveal_child = false;
    expandRevealer.reveal_child = false;
  });
  eventBox.add_controller(motionController);

  // Add click controller
  const clickController = new Gtk.GestureClick();
  clickController.connect("pressed", () => {
    if (popup) {
      lockButton.activate();
    } else {
      copyButton.activate();
    }
  });
  eventBox.add_controller(clickController);

  eventBox.append(mainRevealer);

  // Parent container with auto-close timeout
  const parent = new Gtk.Box({ visible: true });
  parent.append(eventBox);

  // Auto-close timeout for popups
  if (popup) {
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, NOTIFICATION_DELAY, () => {
      if (!isLocked && popup) closeNotification();
      return false;
    });
  }

  return parent;
};
