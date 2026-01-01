import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import Notification from "./rightPanel/components/Notification";
import { createState, createComputed, With, For, Accessor } from "ags";
import { DND, globalMargin } from "../variables";

// see comment below in constructor
const TIMEOUT_DELAY = 3000;

// The purpose if this class is to replace Variable<Array<Widget>>
// with a Map<number, Widget> type in order to track notification widgets
// by their id, while making it conveniently bindable as an array
class NotificationMap {
  // the underlying notificationMap to keep track of id widget pairs
  private notificationMap: Map<number, any> = new Map();

  // it makes sense to use a Variable under the hood and use its
  // reactivity implementation instead of keeping track of subscribers ourselves
  private notifications: Accessor<Array<any>>;
  private setNotifications: (value: Array<any>) => void;

  // notify subscribers to rerender when state changes
  private notify() {
    this.setNotifications([...this.notificationMap.values()].reverse());
  }

  constructor() {
    const [notifications, setNotifications] = createState<Array<any>>([]);
    this.notifications = notifications;
    this.setNotifications = setNotifications;

    const notifd = Notifd.get_default();

    /**
     * uncomment this if you want to
     * ignore timeout by senders and enforce our own timeout
     * note that if the notification has any actions
     * they might not work, since the sender already treats them as resolved
     */
    // notifd.ignoreTimeout = true

    notifd.connect("notified", (_, id) => {
      print(`[NotificationPopups] Received notification id: ${id}, DND: ${DND()}`);
      if (DND()) {
        print(`[NotificationPopups] DND is enabled, ignoring notification`);
        return;
      }
      const notification = notifd.get_notification(id);
      if (!notification) {
        print(`[NotificationPopups] Could not get notification for id: ${id}`);
        return;
      }
      print(`[NotificationPopups] Creating notification widget for: ${notification.summary}`);

      let timeoutId: number | null = null;
      let hideFunc: (() => void) | null = null;

      this.set(
        id,
        Notification({
          n: notification,
          newNotification: true,
          isPopup: true,
          onClose: () => {
            // Cancel the auto-timeout if manually closed
            if (timeoutId !== null) {
              clearTimeout(timeoutId);
              timeoutId = null;
            }
            setTimeout(() => {
              this.delete(id);
            }, 200); // Wait for animation to complete
          },
          onHide: (func) => {
            hideFunc = func;
          },
        })
      );

      // Auto-remove notification from popup after delay
      // Don't dismiss from daemon to keep in history
      timeoutId = setTimeout(() => {
        if (this.notificationMap.has(id) && hideFunc) {
          // Trigger close animation via the notification's hide function
          hideFunc();
        }
      }, TIMEOUT_DELAY) as any;
    });

    // notifications can be closed by the outside before
    // any user input, which have to be handled too
    notifd.connect("resolved", (_, id) => {
      // Remove from popup when dismissed from history or externally
      if (this.notificationMap.has(id)) {
        setTimeout(() => {
          this.delete(id);
        }, 200); // Wait for animation to complete
      }
    });
  }

  private set(key: number, value: any) {
    // in case of replacement, unparent previous widget (GTK4 doesn't have destroy())
    const oldWidget = this.notificationMap.get(key);
    if (oldWidget?.parent) {
      oldWidget.unparent();
    }
    this.notificationMap.set(key, value);
    this.notify();
  }

  private delete(key: number) {
    // GTK4: use unparent() instead of destroy()
    const widget = this.notificationMap.get(key);
    if (widget?.parent) {
      widget.unparent();
    }
    this.notificationMap.delete(key);
    this.notify();
  }

  // needed by the Subscribable interface
  get() {
    return this.notifications;
  }

  // needed by the Subscribable interface
  subscribe(callback: (list: Array<any>) => void) {
    // In the new system, we might not need subscribe if we use the accessor directly in JSX
    // But for compatibility if needed:
    // return this.notifications.subscribe(callback);
    // Since we are using createComputed or just passing the accessor, we can just return a cleanup function or similar
    // However, for this specific case, we can just expose the accessor.
    return () => {};
  }
}

// Global singleton instance to prevent multiple notification listeners
let globalNotifications: NotificationMap | null = null;

export default (monitor: Gdk.Monitor) => {
  const { TOP, RIGHT } = Astal.WindowAnchor;

  // Use global singleton instance to prevent duplicate notifications
  if (!globalNotifications) {
    print("\t\t Creating NEW NotificationMap instance");
    globalNotifications = new NotificationMap();
  } else {
    print("\t\t Reusing EXISTING NotificationMap instance");
  }

  const notifications = globalNotifications.get();

  return (
    <window
      gdkmonitor={monitor}
      class="NotificationPopups"
      name="notification-popups"
      namespace="notification-popups"
      application={App}
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT}
      margin={globalMargin}
      widthRequest={400}
      visible={true}
      resizable={false}
    >
      <box
        class={"notification-popups"}
        orientation={Gtk.Orientation.VERTICAL}
        vexpand={true}
        spacing={5}
      >
        <For each={notifications}>{(n) => n}</For>
      </box>
    </window>
  );
};
