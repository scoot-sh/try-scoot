# Selkies variant (`:selkies` tag): design, trade-offs, measurements

Second, opt-in image. The default tag stays wayvnc + noVNC (smallest,
one-port, ~0% idle); this tag streams the same desktop through Selkies
instead. Status: **experimental** -- it streams, with the limits listed
below. The default image and its one-liner are unchanged by everything here.

## Run

```sh
docker run --rm -p 127.0.0.1:8080:8080 ghcr.io/scoot-sh/try-scoot:selkies
```

Open `http://localhost:8080/`. With no password configured the login is off
and the port must stay on loopback, exactly like the default tag's posture.
With a password it is fail-closed (see Security below):

```sh
docker run --rm -p 127.0.0.1:8080:8080 -e SELKIES_BASIC_AUTH_PASSWORD='...' ghcr.io/scoot-sh/try-scoot:selkies
```

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
- Input reaches scoot as virtual-keyboard/pointer events into the nested
  session. Typing and pointing work; compositor keybindings do not fire from
  remote input -- scoot's virtual-input path is a forward-only filter by
  design (remote keys reach clients but never run keybindings; established
  for the VNC path in docs/benchmark.md and identical here because the
  mechanism is the same protocol). Drive chords via `scoot msg key` /
  `scoot msg pointer` from inside the container, as with the default tag.
  Note the client also keeps some of its own chords by default
  (`SELKIES_KEYBOARD_SHORTCUTS`); turn that off if a session app binds the
  same ones.

## Security

Posture matches the default tag, with the enforcement in Selkies itself:

- **Loopback by published port, not by bind.** `SELKIES_ADDR` defaults to
  `0.0.0.0` in the container (a container-loopback bind is unreachable
  through a `-p` mapping); the documented command publishes to host
  loopback only (`-p 127.0.0.1:8080:8080`). Reaching it from elsewhere takes
  `ssh -L` or an explicit wider publish, same trade as the default tag's
  browser port. `SELKIES_ADDR=localhost` remains available for setups that
  do not publish the port at all.
- **Auth is fail-closed and never decorative.** With basic auth at its
  default (on) the server refuses to start until a password is actually
  supplied (`SELKIES_BASIC_AUTH_PASSWORD`, `PASSWORD`, or `PASSWD`) -- an
  unset password is a startup error, not an open port. This image only turns
  the login off when no password is configured at all (the loopback
  default); a configured password always turns it on, and an explicit
  `SELKIES_ENABLE_BASIC_AUTH` wins in both directions. There is no separate
  try-scoot password knob that could be accepted but ignored. Wrong
  passwords get 401 (constant-time comparison, no user enumeration by
  timing); proven live in the PR report. `SELKIES_BASIC_AUTH_USER` (default
  `ubuntu`) sets the username.
- **Origin, and what it does not cover.** WebSocket upgrades and the
  mode-switch/control POSTs are held to an Origin rule: with
  `SELKIES_ALLOWED_ORIGINS` empty (default) only same-origin requests and
  non-browser clients (no `Origin` header) pass; anything else gets 403.
  What this is not: there is no Host pin on the Selkies server, so a
  rebound-DNS host whose page names that same host passes the Origin check
  the way it would pass any same-origin test. What still holds then: every
  route but the health endpoints sits behind the login (or a master/session
  token where configured), and a cross-site page carries no credentials for
  the rebound origin -- so a rebinding attacker without the password gets
  the login page at most, never the session. The static UI carries no
  credentials and performs no state-changing GETs. Keep the port on
  loopback (or set a password) and this composes the same way the default
  tag's Host pin plus loopback default does.
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
`-selkies` tags on the same main-only / same-repo-PR scheme as the default
(`:selkies` tracks main only).

## Measurements

All live numbers below are Mac Docker Desktop (arm64) runs of the images
built on the Asahi M2, unless stated. Method matches the default tag's
(tarball bytes for pull, `docker export` for unpacked, `docker stats` after
a 30 s settle for idle).

| layer | pull (tarball) | unpacked (`docker export`) | idle CPU / RAM |
|---|---|---|---|
| VNC final (`:latest`) | 185,474,953 B (176.9 MiB) | 593,991,680 B (566.4 MiB) | 0.00% / ~43 MiB (no viewer); 0.00% / ~49 MiB (viewer) |
| Selkies L0 (compositor only) | 494,739,938 B (471.8 MiB) | 1,691,484,160 B (1.575 GiB) | 0.18% / 71.7 MiB (no viewer) |
| Selkies full (`:selkies`) | 514,428,977 B (490.6 MiB) | 1,753,701,888 B (1.633 GiB) | 0.26% / 119.2 MiB (no viewer); 0.19% / 123.9 MiB (viewer attached, static screen, NET 20.2 kB rx / 2.32 MB tx over the session) |

So the Selkies full tag costs ~2.8x the pull and ~3x the unpacked bytes
and RAM of the VNC tag, for audio + H.264. The desktop itself (scoot set)
is only ~20 MB of the gap; the rest is the GL + Python + PulseAudio stack
the VNC tag deleted on purpose. Idle CPU stays near zero on a static
screen in both tags (Selkies' damage model ships almost nothing when
nothing moves; motion would encode at up to 60 fps in software -- not
measured here, and that is where the idle gap would open).

Time from `docker run` to stream (full tag): HTTP 200 at 1.05 s, first
client's settings applied (1280x800, h264enc) at 1.6 s, painted desktop in
a persistent headless-Chromium connection in the same session
(screenshots: bar, terminal, typed command executing). The encoder runs
software H.264 (x264, 47.77 EncFPS observed during the initial stream; no
GPU anywhere in the path).

Auth (live, full tag with `SELKIES_BASIC_AUTH_PASSWORD=secret1234`):
page with no creds -> 401, wrong password -> 401, right password -> 200;
WebSocket handshake with no creds -> 401, wrong password -> 401 (plus an
`Invalid credentials` server log), right password -> 101. Foreign
`Origin` on the WS upgrade -> 403; no `Origin` (non-browser clients) ->
101 alongside same-origin.

Input (live, full tag): `scoot msg binds` lists the config binds;
`scoot msg key alt+Return` spawns a terminal (1 -> 2 windows);
`scoot msg type 'echo hello-selkies'` + Return executes in the focused
terminal (screenshot). Remote chords were not driven live in this round
(the WS input protocol is binary opcodes, not scriptable with stdlib in
the time available); the stated behavior -- typing/pointing arrive,
compositor binds never fire from remote input -- rests on the mechanism:
Selkies' Wayland input path is a virtual-keyboard client into the nested
compositor, the same protocol the VNC tag uses, so scoot's forward-only
virtual-input filter applies identically (see docs/benchmark.md).
