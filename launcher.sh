#!/bin/bash

export LD_LIBRARY_PATH="$HOME/.config/quickshell/chillpill-shell/IslandBackend:$LD_LIBRARY_PATH"
export QML_IMPORT_PATH="/usr/share/chillpill-shell:$QML_IMPORT_PATH"

# A terminal that outlived a previous Hyprland session still carries that
# session's HYPRLAND_INSTANCE_SIGNATURE; launched from there the shell can't
# reach Hyprland (no workspaces). Swap in the newest live instance if so.
hypr_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
if [[ ! -S "$hypr_dir/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]]; then
  for sock in $(ls -td "$hypr_dir"/*/.socket.sock 2>/dev/null); do
    sig=$(basename "$(dirname "$sock")")
    if HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl -j version >/dev/null 2>&1; then
      export HYPRLAND_INSTANCE_SIGNATURE="$sig"
      break
    fi
  done
fi

exec qs -p /usr/share/chillpill-shell
