#!/bin/bash
# try-scoot session: publish the Wayland socket for wayvnc, keep the bar alive.
LOG="${XDG_RUNTIME_DIR:-/tmp}/session.log"

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  echo "$WAYLAND_DISPLAY" > "$XDG_RUNTIME_DIR/scoot-display"
  echo "[session] display $WAYLAND_DISPLAY" >> "$LOG"
fi

# Start a terminal so first frame has content.
if [ -z "${SKIP_AUTOSTART_TERMINAL:-}" ]; then
  foot --hold sh -c 'echo "Welcome to try-scoot. Alt+Return opens a terminal. Alt+d opens the launcher."; exec sh' >> "$LOG" 2>&1 &
fi

sleep 4
while true; do
  if command -v scoot-bar-look >/dev/null 2>&1; then
    if ! pgrep -x scootbar >/dev/null 2>&1; then
      scoot-bar-look >> "$LOG" 2>&1 &
    fi
  fi
  sleep 10
done
