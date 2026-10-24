#!/bin/bash
# try-scoot session: publish the Wayland socket for wayvnc, keep the bar alive.
# First-run content (the bash terminal beside btop) comes from scoot's own
# [autostart] spawns, in order, so this script only supervises the bar.
LOG="${XDG_RUNTIME_DIR:-/tmp}/session.log"

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  echo "$WAYLAND_DISPLAY" > "$XDG_RUNTIME_DIR/scoot-display"
  echo "[session] display $WAYLAND_DISPLAY" >> "$LOG"
fi

sleep 4
while true; do
  if command -v scoot-bar-look >/dev/null 2>&1; then
    if ! pgrep -x scootbar >/dev/null 2>&1; then
      scoot-bar-look >> "$LOG" 2>&1 &
    fi
  fi
  # Notification daemon from the desktop profile (scootnotify): runs
  # headless on the session bus, popups on the overlay layer. No
  # systemd user manager in the container, so supervise it here like
  # the bar. If it does not start (missing bus/wayland), binds fail
  # quietly and the desktop still comes up.
  if command -v scootnotify >/dev/null 2>&1; then
    if ! pgrep -x scootnotify >/dev/null 2>&1; then
      scootnotify daemon >> "$LOG" 2>&1 &
    fi
  fi
  sleep 10
done
