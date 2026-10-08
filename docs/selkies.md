# Selkies variant (`:selkies` tag): design, trade-offs, measurements

Second, opt-in image. The default tag stays wayvnc + noVNC (smallest,
one-port, ~0% idle); this tag streams the same desktop through Selkies
instead. Status: **experimental** -- it streams, with the limits listed
below. The default image and its one-liner are unchanged by everything here.

## Run

```sh
docker run --rm -p 127.0.0.1:8080:8080 ghcr.io/scoot-sh/try-scoot:selkies
docker logs <container>  # read the generated password (printed once at startup)
```

The server is fail-closed by default: with no password configured it
generates a random one, prints it to the container log, and keeps the
login on (if the server process restarts inside the container, a new
password is generated: always use the last `GENERATED` line, or set your own) -- the one-liner above works and is safe (a DNS-rebound page
carries no credentials for the rebound origin, so without the password it
gets 401 on every session route, proven live in the PR report). To choose
your own password instead of reading the log:

```sh
docker run --rm -p 127.0.0.1:8080:8080 -e SELKIES_BASIC_AUTH_PASSWORD='...' ghcr.io/scoot-sh/try-scoot:selkies
```

The old open mode (no login at all) is still available, but only as an
explicit opt-in, and only on loopback:

```sh
docker run --rm -p 127.0.0.1:8080:8080 -e TRY_SCOOT_INSECURE_OPEN=1 ghcr.io/scoot-sh/try-scoot:selkies
```

`VNC_WIDTH`/`VNC_HEIGHT` (default `1280x800`) and `XKB_DEFAULT_LAYOUT`
(default `us`) are shared knobs: they drive this variant too
(`startwm-selkies.sh`), exactly as on the default tag.

## Why websockets mode, not WebRTC, for the documented command

Upstream Selkies carries both transports in one package (`--mode
websockets|webrtc`, default `websockets`); both capture through the same
pixelflux/pcmflux pipeline, so the encoder and audio story below holds for
either. The transports differ in what the `docker run` line must be:

- **WebSockets mode (shipped default): one TCP port.** The server fronts its
  HTTP UI and the streaming WebSocket on `SELKIES_PORT` (8080), bound to
  `0.0.0.0` in the container with the publish flag as the boundary
  (`-p 127.0.0.1:8080:8080` keeps it on host loopback -- a
  container-loopback bind would be unreachable through the mapping, the same
  reason the default tag's browser bridge binds `0.0.0.0`). No UDP
  publishes, no STUN/TURN, no host networking. The `docker run` line above
  is the whole story, mirroring the default tag's single-port goal.
- **WebRTC mode (env switch): UDP + setup.** Media rides WebRTC, which needs
  UDP reachability plus ICE helpers: STUN defaults at
  `stun.l.google.com:19302` and TURN at a public relay with a public shared
  secret -- both wrong for a loopback-grade one-liner (they send traffic to
  third parties and need real NAT traversal even locally). Confining the
  media to publishable ports takes either a UDP port range
  (`SELKIES_WEBRTC_PORT_RANGE="50000-50100"` plus matching `-p` flags), the
  single-port UDP mux (`SELKIES_WEBRTC_UDP_MUX_PORT=59000` plus `-p
  59000:59000/udp`), or `--network host`:

```sh
# WebRTC via the single-port UDP mux (one extra published port):
docker run --rm -p 127.0.0.1:8080:8080 -p 127.0.0.1:59000:59000/udp \
  -e SELKIES_MODE=webrtc -e SELKIES_WEBRTC_UDP_MUX_PORT=59000 \
  ghcr.io/scoot-sh/try-scoot:selkies
```

WebRTC mode is accepted on these terms and otherwise untested here; the
numbers below are websockets mode unless stated.

## What the variant is

- Same desktop seeding as the default tag (scoot config, bar, foot,
  launcher, palette look), so both tags show the same session.
- Selkies 2.0.0 serves its bundled web UI and the stream itself; there is no
  VNC server, no noVNC tree, and no nginx in this image. The compositor is
  pixelflux's own (Selkies' Wayland backend); scoot runs nested inside it
  (`scoot --nested`), which is also the input target.
- Encoder: default `h264enc`, which uses the GPU where the host encodes the
  codec and falls back to the software encoder the capture build carries
  (x264) where it does not -- no GPU required, at software-encode CPU cost.
  Audio: server-to-client Opus from a container-local PulseAudio null sink
  monitor (on by default; the image carries the daemon for it).
- Input reaches scoot through the Selkies compositor's seat keymap --
  real seat input to the nested session, not virtual-keyboard input.
  Typing and pointing work AND compositor keybindings fire from remote
  chords (proven live: remote Alt+Return spawns a terminal, 1 -> 2
  windows). This differs from the default tag's pre-#2 story on purpose:
  scoot's `[virtual_input] binds` flag governs virtual-keyboard clients
  only, so it is a no-op on this seat path (which is why
  `nix/image-selkies.nix` deliberately does not set it -- see the comment
  there). Treat WebSocket reach as shell-equivalent: keep the port on
  loopback or set a password, mirroring the warning the default README
  carries since PR #2. Agents can also drive chords via `scoot msg key` /
  `scoot msg pointer` from inside the container. Note the client also
  keeps some of its own chords by default (`SELKIES_KEYBOARD_SHORTCUTS`);
  turn that off if a session app binds the same ones.

## Security

Posture matches the default tag, with the enforcement in Selkies itself:

- **Loopback by published port, not by bind.** `SELKIES_ADDR` defaults to
  `0.0.0.0` in the container (a container-loopback bind is unreachable
  through a `-p` mapping); the documented command publishes to host
  loopback only (`-p 127.0.0.1:8080:8080`). Reaching it from elsewhere takes
  `ssh -L` or an explicit wider publish, same trade as the default tag's
  browser port. `SELKIES_ADDR=localhost` remains available for setups that
  do not publish the port at all.
- **Auth is fail-closed and never decorative.** The Selkies server has no
  Host pin, and it cannot tell a rebound Host apart: a page on
  `evil.example` rebound to 127.0.0.1 sends `Host: evil.example:8080`
  with `Origin: http://evil.example:8080`, which passes the Origin check
  the way any same-origin test would. Auth is therefore the defense --
  never "login page at most". This image enforces it three ways: a
  configured password (`SELKIES_BASIC_AUTH_PASSWORD`, `PASSWORD`, or
  `PASSWD`) always turns the login on; with no password it generates a
  random one at startup, prints it once to the container log (`docker
  logs`), and keeps the login on; only an explicit
  `TRY_SCOOT_INSECURE_OPEN=1` (or an explicit
  `SELKIES_ENABLE_BASIC_AUTH=false`) starts open, with a loud warning, for
  loopback demos. An explicit `SELKIES_ENABLE_BASIC_AUTH=true` with no
  password refuses to start upstream (clear error, non-zero service
  exit). There is no separate try-scoot password knob that could be
  accepted but ignored. Wrong passwords get 401 (constant-time
  comparison, no user enumeration by timing); proven live in the PR
  report. `SELKIES_BASIC_AUTH_USER` (default `ubuntu`) sets the username.
  Basic auth has no rate limit (unbounded online guessing; constant-time
  compare only) -- same accepted tradeoff as the default tag's VNC
  password: keep the port on loopback or tunnel over SSH, and prefer
  strong generated passwords.
- **File transfers are off by default; recording is auth-gated.** A demo
  does not need them, and both were open routes in the open default, so
  this image passes `--file-transfers=none` (`SELKIES_FILE_TRANSFERS`;
  set it to `upload,download`, or `TRY_SCOOT_ENABLE_FILE_TRANSFERS=1`
  for the upstream default, to opt back in). Recording
  (`/api/recording`) has no upstream disable switch -- only
  `SELKIES_RECORDING_SOCKET` for the out-of-band tap (default off); the
  endpoint itself is always served when pixelflux is present -- so it
  stays behind the login enforced above instead of disabled. With the
  default generated password, an unauthenticated rebind-shaped request
  gets 401 on `/`, `/api/websockets`, `/api/sessions`,
  `/api/recording`, `/api/switch`, `/api/screenshot`, `/api/upload`,
  and `/api/files/` alike (only the liveness probes `/api/status` and
  `/api/health` answer 200 without credentials, by upstream design).
- **Origin, and what it does not cover.** WebSocket upgrades and the
  mode-switch/control POSTs are held to an Origin rule: with
  `SELKIES_ALLOWED_ORIGINS` empty (default) only same-origin requests and
  non-browser clients (no `Origin` header) pass; anything else gets 403.
  What this is not: there is no Host pin on the Selkies server, so a
  rebound-DNS host whose page names that same host passes the Origin check
  the way it would pass any same-origin test -- the server cannot tell a
  rebound Host apart. What still holds then is the login above: every
  route but the health endpoints sits behind basic auth (or a
  master/session token where configured), and a cross-site page carries no
  credentials for the rebound origin -- so a rebinding attacker without
  the password gets 401, never the session. The static UI carries no
  credentials and performs no state-changing GETs. Keep the port on
  loopback (or set a password -- the default is now a generated one) and
  this composes the same way the default tag's Host pin plus loopback
  default does.
- **Non-root.** The session runs as `abc` (uid 911, same `PUID`/`PGID`
  mapping as the default tag); Selkies, PulseAudio, and scoot all run under
  it. No `--privileged`, no DRI devices, no GPU flags.
- **No TURN secret ships.** WebRTC's default STUN/TURN point at public
  services; they are only contacted in WebRTC mode. Websockets mode (the
  documented command) makes no third-party network contact.

## Packaging notes

`nix/selkies-stack.nix` builds the stack from upstream wheels (fixed-output
fetches, hashes pinned): the `selkies` application wheel (which bundles its
prebuilt web UI, so no npm build runs and no lockfiles are vendored) plus
the `pixelflux`/`pcmflux` capture wheels via autoPatchelf. The Python
dependency list is the wheel's own closure (imports plus METADATA runtime
requirements); anything that closure does not import is left out until a
build names it. `nix/image-selkies.nix` assembles the two layers; the
default image's builder is untouched. CI builds and pushes per-arch
`-selkies` tags in isolated `build-selkies`/`push-selkies` jobs (the
default's `build`/`push` never depend on or wait for the variant; the
default's CI time stays ~2 min) on the same main-only / same-repo-PR
scheme as the default (`:selkies` tracks main only).

## Measurements

All live numbers below are Mac Docker Desktop (arm64) runs of the images
built on the Asahi M2, unless stated. Method matches the default tag's
(tarball bytes for pull, `docker export` of a created-but-never-started
container for unpacked, `docker stats` after a 30 s settle for idle).

| layer | pull (tarball) | unpacked (`docker export`) | idle CPU / RAM |
|---|---|---|---|
| VNC (`:latest`, scoot `134e39a`, ginger-night) | 186,881,227 B (178.2 MiB) | 598,816,768 B (571.1 MiB) | 0.00% / 59.9 MiB (no viewer, 2 windows) |
| Selkies L0 (compositor only) | 494,742,034 B (471.8 MiB) | 1,686,177,792 B (1.571 GiB) | 0.18% / 71.7 MiB (no viewer; prior round) |
| Selkies full (`:selkies`, ginger-night) | 515,831,613 B (492.0 MiB) | 1,753,213,440 B (1.633 GiB) | 0.19–0.27% / ~119 MiB (no viewer); 27–48% / ~143 MiB (viewer attached, static screen, actively streaming) |

Reviewed baselines: the default tag's pre-#2 numbers were 185,480,055 B
pull and 593,971,200 B unpacked (revts4, byte-exact); PR #2's scoot bump
(+`binds = true`) added 11,940 B to the tarball (this head's default
tarball is byte-exact to main's build: same store path). Exporting a
*running* container instead adds live state (full tag: 1,753,725,440 B
running vs 1,748,387,328 B created) -- created-container numbers are the
stable comparison.

So the Selkies full tag costs ~2.8x the pull and ~3x the unpacked bytes
and RAM of the VNC tag, for audio + H.264. The desktop itself (scoot set)
is only ~20 MB of the gap; the rest is the GL + Python + PulseAudio stack
the VNC tag deleted on purpose. Idle CPU without a viewer stays near zero
in both tags; with a viewer attached the Selkies tag encodes continuously
at 60 fps in software (server log: `FullFrame Streaming ... 60 fps` +
`software H264 (x264)`), which is the expected cost -- the old "~0.2%
with viewer" claim came from a backgrounded/frozen client, not an
actively streaming one, and is corrected above.

Time from `docker run` to stream (full tag): HTTP 200 at 1.05 s, first
client's settings applied (1280x800, h264enc) at 1.6 s, painted desktop in
a persistent headless-Chromium connection in the same session
(screenshots: bar, terminal, typed command executing). The encoder runs
software H.264 (x264, 47.77 EncFPS observed during the initial stream; no
GPU anywhere in the path).

Auth (live, full tag): default run (no password configured) generates a
password, prints it once to the container log, and keeps the login on --
page/WS with no creds -> 401, wrong password -> 401, right password ->
200/101 (plus an `Invalid credentials` server log on wrong). Rebind-shaped
requests (`Host: evil.example:8080` + matching `Origin`, no creds) get
401 on `/`, `/api/websockets`, `/api/sessions`, `/api/recording` (GET and
POST), `/api/switch`, `/api/screenshot`, `/api/upload`, and `/api/files/`
alike; foreign `Origin` on the WS upgrade -> 403; no `Origin`
(non-browser clients) -> 101 alongside same-origin. With
`SELKIES_BASIC_AUTH_PASSWORD=secret1234`: page 401/401/200 and WS
handshake 401/401/101 for none/wrong/right. With
`SELKIES_FILE_TRANSFERS=upload,download` + password: upload/download
succeed with auth (200) and stay 401 without. Correct password works in a
real headless browser (page loads past the login; server-side
`/api/screenshot` returns a real PNG desktop).

Input (live, full tag, reviewer-proven): remote Alt+Return spawns a
terminal (1 -> 2 windows, both `app_id: foot`; screenshot shows two
side-by-side terminals), and typing executes (`echo hello-selkies`
visible in the screenshot). Typing/pointing arrive AND compositor binds
fire -- treat WebSocket reach as shell-equivalent (see above).

Audio (live): server `Starting pcmflux audio pipeline ... 128000 bps 2ch`
+ `Opus encoder created (2 ch)`; silence-gated as coded. Boot logs
~16x PulseAudio `Failed to connect to system bus ... /run/dbus/...
No such file or directory`: audio itself works (null-sink monitor
proven). No one-line setting quiets it (`DBUS_SESSION_BUS_ADDRESS` /
`DBUS_SYSTEM_BUS_ADDRESS=disabled:` only reword the error, measured) --
accepted as log spam, noted not fixed.
