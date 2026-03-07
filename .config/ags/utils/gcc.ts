import { exec } from "ags/process";

export async function compileBinaries() {
  exec(`bash -c "mkdir -p /tmp/ags"`);
  exec(
    `gcc -o /tmp/ags/bandwidth-loop-ags ./scripts/bandwidth-loop-ags.c`,
  );
  exec(
    `gcc -o /tmp/ags/system-resources-loop-ags ./scripts/system-resources-loop-ags.c`,
  );
  exec(
    `gcc -o /tmp/ags/keystroke-loop-ags ./scripts/keystroke-loop-ags.c`,
  );
}
