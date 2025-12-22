import { Accessor, createComputed } from "ags";
import Gio from "gi://Gio?version=2.0";
import Gtk from "gi://Gtk?version=4.0";

// Helper to safely create Gio.File from path
function safeGioFile(path: string | null | undefined): Gio.File | null {
  if (!path || path.trim() === "") {
    return null;
  }
  try {
    return Gio.File.new_for_path(path);
  } catch (e) {
    console.error("Failed to create Gio.File for path:", path, e);
    return null;
  }
}

interface PictureProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file: Accessor<string> | string;
  contentFit?: Gtk.ContentFit;
  $?: (self: Gtk.Picture) => void;
}
export default function Picture({
  class: className,
  height,
  width,
  file,
  contentFit = Gtk.ContentFit.COVER,
  $,
}: PictureProps) {
  let pictureRef: Gtk.Picture | undefined;

  // Create a computed binding that safely handles null/empty paths
  const fileBinding = typeof file === "string"
    ? safeGioFile(file)
    : createComputed(() => {
        const path = typeof file === "function" ? file() : null;
        return safeGioFile(path);
      });

  return (
    <overlay
      heightRequest={height}
      widthRequest={width}
      $={(self) => {
        const children = self.observe_children();
        const count = children.get_n_items();

        for (let i = 0; i < count; i++) {
          const child = children.get_item(i);

          if (child instanceof Gtk.Picture) {
            pictureRef = child;
          }
        }

        // ⚡ expose helper method
        (self as any).getPicture = () => pictureRef;
      }}
    >
      <Gtk.Picture
        $type="overlay"
        class={"image " + className}
        file={fileBinding}
        contentFit={contentFit}
        $={(self) => {
          // also capture directly (more reliable)
          pictureRef = self;
        }}
      />
    </overlay>
  );
}
