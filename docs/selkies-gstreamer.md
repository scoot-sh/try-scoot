# Selkies GStreamer packaging: research and decision

The brief asks for Selkies GStreamer (WebRTC, GStreamer-based Selkies, not
the pixelflux/websocket one). What we found:

- nixpkgs carries no `selkies` package. Packaging means a fresh
  `buildPythonApplication` from `selkies-project/selkies` (MPL-2.0,
  unmodified), plus its capture wheels (`pixelflux`/`pcmflux`: manylinux
  wheels + autoPatchelf, no sdist) and its web client (npm workspaces:
  `selkies-web-core`, `selkies-dashboard`, `selkies-dashboard-wish`; build
  reproducibly with `buildNpmPackage`, vendored lockfiles, fixed-output
  `npmDepsHash` fetches; no network at build time beyond fixed-output
  fetches; the `gendb.js` gamepad-database fetch must be vendored via
  `fetchurl` like the reference does).
- Upstream `selkies` main (2.0.0+) carries BOTH transports in one package
  (`--mode websockets|webrtc`), and BOTH capture through
  pixelflux/pcmflux: the WebRTC media pipeline (`webrtc_media_pipeline.py`)
  imports pixelflux `ScreenCapture`, not GStreamer elements. The vendored
  `webrtc/` stack is an aiortc fork. GStreamer in nixpkgs (`gst_all_1`,
  1.28.x, plus `libnice` for `webrtcbin`) would serve a from-scratch WebRTC
  pipeline (test pattern `videotestsrc` for Layer 0, then
  `waylanddisplaysrc`/`ximagesrc` + `x264enc` + `webrtcbin`), but that is a
  second streaming stack to build, signal, and maintain beside selkies.
- Cost of Selkies here: the npm web build, nginx, PulseAudio daemon, and a
  60 fps software x264 encode at idle (reference benchmark: Selkies idle
  ~5% CPU / ~11 KB/s vs VNC ~0% / ~0.9 KB/s on the same host). Ports grow
  from one TCP port to HTTP(S) + WebRTC UDP + STUN/TURN, which breaks the
  one-line `-p 127.0.0.1:PORT:PORT` goal (needs a UDP port range or host
  networking guidance plus TURN secrets in CI, which we do not have).

Decision: ship wayvnc + noVNC for the one-liner (single TCP port 6080,
damage-based, idles near zero, smallest closure: no npm, no nginx, no
pulse daemon, no pixelflux wheels). Layer 0 below proves the same
"smallest thing that streams" with VNC instead of Selkies/GStreamer. The
Selkies WebRTC/GStreamer variant stays a backlog item (ticket T1): re-add
it when the image needs audio + H.264 motion efficiency enough to pay the
size, idle, and ports cost. Nothing in `nix/` is copied from the reference;
the packaging notes above are written from upstream sources so a future
`nix/selkies.nix` can be fresh MIT work.
