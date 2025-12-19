import { createState } from "ags";
import { execAsync } from "ags/process";
import GLib from "gi://GLib?version=2.0";
import Gtk from "gi://Gtk?version=4.0";
import Pango from "gi://Pango?version=1.0";
import Notifd from "gi://AstalNotifd";
import { globalTransition, NOTIFICATION_DELAY } from "../../../variables";
import { notify } from "../../../utils/notification";
import { time } from "../../../utils/time";
import Picture from "../../Picture";

const [wrapText, setWrapText] = createState<boolean>(false);

const TRANSITION = 200;

function NotificationIcon(n: Notifd.Notification): JSX.Element {
  const notificationIcon = n.image || n.app_icon || n.desktopEntry;

  if (!notificationIcon) {
    return (
      <image iconName="dialog-information-symbolic" class="icon" />
    );
  }

  return (
    <Picture file={notificationIcon} class="icon" />
  );
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
  isPopup = false,
  onClose,
  onHide,
}: {
  n: Notifd.Notification;
  newNotification?: boolean;
  isPopup?: boolean;
  onClose?: () => void;
  onHide?: (hideFunc: () => void) => void;
}) => {
  const [IsLocked, setIsLocked] = createState<boolean>(false);

  let Revealer: Gtk.Revealer;

  async function closeNotification(dismiss = false) {
    if (Revealer) {
      Revealer.reveal_child = false;
    }
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, globalTransition, () => {
      // Only dismiss from daemon when in history (not popup)
      // This keeps notifications in history even when popup is closed
      if (dismiss && !isPopup) {
        n.dismiss();
      }
      // Always call onClose to remove from popup map
      if (onClose) onClose();
      return false;
    });
  }

  const icon = (
    <box valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER} class="icon">
      {NotificationIcon(n)}
    </box>
  );

  const title = (
    <label
      class="title"
      xalign={0}
      justify={Gtk.Justification.LEFT}
      maxWidthChars={24}
      wrap={true}
      label={GLib.markup_escape_text(n.summary || "", -1)}
      useMarkup={true}
    />
  );

  const body = (
    <label
      class="body"
      label={n.body}
      wrap={true}
      wrapMode={Pango.WrapMode.WORD_CHAR}
      lines={2}
      vexpand={false}
    />
  );

  const expand = (
    <togglebutton
      class="expand"
      active={false}
      onToggled={(self) => {
        setWrapText(self.active);
      }}
      label={wrapText((wrap) => (wrap ? "" : ""))}
    />
  );

  const lockButton = (
    <togglebutton
      class="lock"
      label=""
      onToggled={(self) => {
        setIsLocked(self.active);
      }}
    />
  );

  const copyButton = (
    <button
      class="copy"
      label=""
      onClicked={() => copyNotificationContent(n)}
    />
  );

  const close = (
    <button
      class="close"
      label=""
      onClicked={() => {
        closeNotification(true);
      }}
    />
  );

  const topBar = (
    <box class="top-bar" spacing={5}>
      <box spacing={5}>
        <box visible={isPopup} class="circular-progress-box">
        </box>
        <label wrap={true} class="app-name" label={n.app_name} />
        {copyButton}
      </box>
      <box class={"separator"} hexpand />
      <box class="quick-actions">
        {close}
      </box>
      <label halign={Gtk.Align.END} class="time" label={time(n.time)} />
    </box>
  );

  const Box = (
    <box
      class={`notification ${n.urgency} ${n.app_name}`}
      hexpand
      orientation={Gtk.Orientation.VERTICAL}
    >
      {topBar}
      <box spacing={5}>
        {icon}
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {title}
          {body}
        </box>
      </box>
    </box>
  );

  const RevealerElement = (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
      transitionDuration={TRANSITION}
      reveal_child={!newNotification}
      $={(self) => {
        Revealer = self;
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1, () => {
          self.reveal_child = true;
          return false;
        });
      }}
    >
      {Box}
    </revealer>
  );

  const Parent = (
    <box
      class="notification-parent"
      visible={true}
      $={(self) => {
        // Only handle resolved signal for popups
        if (isPopup) {
          const handler = n.connect("resolved", () => {
            closeNotification(false);
          });
          self.connect("destroy", () => {
            n.disconnect(handler);
          });
        }

        // Expose hide function to parent via callback
        if (onHide) {
          onHide(() => closeNotification(false));
        }
      }}
    >
      {RevealerElement}
    </box>
  );

  return Parent;
};
