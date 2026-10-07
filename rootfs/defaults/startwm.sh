#!/bin/bash
# Launches the headless scoot compositor for try-scoot.
# Fresh implementation: fixed 1280x800 output, CPU pixman path, no GPU.
ulimit -c 0
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-us}"
export XDG_CURRENT_DESKTOP=scoot
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export GDK_BACKEND=wayland
export ELECTRON_OZONE_PLATFORM_HINT=wayland

W="${VNC_WIDTH:-1280}"; H="${VNC_HEIGHT:-800}"
[ "$W" = "0" ] && W=1280
[ "$H" = "0" ] && H=800

exec scoot --headless --width "$W" --height "$H" --outputs 1 -- /defaults/session.sh
