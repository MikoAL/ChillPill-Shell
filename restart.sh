#!/bin/bash
# Rebuild + reinstall ChillPill, then restart the running shell in the background.
# Run as your normal user (NOT with sudo) — the script sudo's only the install
# step. Launching qs as root loses WAYLAND_DISPLAY and the bar silently dies.

set -e
cd "$(dirname "$0")"   # so ./install.sh resolves no matter where this is run from

if [[ $EUID -eq 0 ]]; then
  echo "run this as your user, not with sudo: ./restart.sh" >&2
  exit 1
fi

sudo ./install.sh --skip-deps

# Kill every instance of this config by asking quickshell itself. A pkill on the
# command line misses instances that quickshell re-exec'd (e.g. after a crash) —
# those show up as plain "/usr/bin/quickshell". Exits non-zero when none run.
qs kill -p /usr/share/chillpill-shell >/dev/null 2>&1 || true
sleep 0.5

LOG=/tmp/chillpill-shell.log
setsid chillpill-shell >"$LOG" 2>&1 < /dev/null &
disown

sleep 2
if qs list -p /usr/share/chillpill-shell 2>/dev/null | grep -q '^Instance'; then
  echo "chillpill-shell restarted (log: $LOG)"
else
  echo "chillpill-shell failed to start — last lines of $LOG:" >&2
  tail -n 20 "$LOG" >&2
  exit 1
fi
