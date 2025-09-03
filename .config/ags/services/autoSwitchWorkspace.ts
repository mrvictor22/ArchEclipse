import hyprland from "gi://AstalHyprland";
import { autoWorkspaceSwitching, focusedWorkspace } from "../variables";

const Hyprland = hyprland.get_default();

const GAMING_WORKSPACE = 10;

Hyprland.connect("notify::clients", () => {
  const clients = Hyprland.clients;

  const hasGamingWindow = clients.some(
    (c) => c.workspace?.id === GAMING_WORKSPACE
  );

  if (
    autoWorkspaceSwitching.get().value &&
    hasGamingWindow &&
    focusedWorkspace.get().id !== GAMING_WORKSPACE
  ) {
    Hyprland.message_async(`dispatch workspace ${GAMING_WORKSPACE}`, () => {});
  }
});
