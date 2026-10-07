#!/bin/bash
# Nested desktop for the Selkies variant: scoot runs inside Selkies'
# compositor (WAYLAND_DISPLAY names the parent socket; set by the de
# service), so Selkies captures and drives it directly. No X server is
# involved anywhere: scoot has no XWayland path to fall back to.
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
