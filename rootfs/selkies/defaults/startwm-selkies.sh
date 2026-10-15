#!/bin/bash
# Nested desktop for the Selkies variant: scoot runs inside Selkies'
# compositor (WAYLAND_DISPLAY names the parent socket; set by the de
# service), so Selkies captures and drives it directly. No X server runs
# here: the nested scoot stays Wayland-only ([xwayland] is not enabled, so
# no Xwayland server is spawned even though scoot v0.2.1 carries the
# support compiled in).
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

exec scoot --nested --width "$W" --height "$H" -- /defaults/session.sh
