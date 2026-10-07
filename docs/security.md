# Security

No password is set by default. The documented `docker run` binds the browser
port to host loopback only (`-p 127.0.0.1:6080:6080`); keep it there. To
reach the desktop from elsewhere, tunnel (`ssh -L 6080:localhost:6080`)
rather than publishing the port.

- VNC listener (`VNC_LISTEN`, default `localhost`; `VNC_PORT`, default
  `5900`): loopback only. Native clients can only reach it by publishing it
  or execing into the container network. Publishing it without auth exposes
  an open desktop -- and publishing alone is not enough: the listener stays
  on container loopback unless `VNC_LISTEN=0.0.0.0` is also set (a bare
  `-p 5900:5900` accepts then EOFs). Both knobs are honored: wayvnc listens
  on `$VNC_LISTEN:$VNC_PORT` (a `VNC_LISTEN` that already contains a port is
  used as-is, `VNC_PORT` then ignored) and the browser bridge dials the same
  target (`0.0.0.0` / `[::]` map back to `localhost`). A `VNC_LISTEN` holding
  a unix socket path is unsupported: both the wayvnc and browser services
  refuse to start loudly (non-zero exit) rather than dialing the wrong port.
- Remote binds are ON in this image (`[virtual_input] binds = true` with
  `enabled = true`, restart-only): any remote client that can reach the VNC
  port can now also spawn programs and run compositor actions through binds
  (a terminal, the launcher, focus/close) -- not just type and click. That is
  the same trust boundary scoot states for `enabled` widened one step (see
  scoot `remote-desktop.md` / `protocols.md`: no security-context support),
  so keep `binds` for sessions the remote user owns (this webtop) and VNC
  reach equivalent to shell. The one-liner's posture is unchanged:
  loopback-only browser port by default with an optional loopback-grade
  `VNC_PASSWORD`; only what reach implies is stronger.
- `VNC_PASSWORD`: when set, the wayvnc service enables password auth and the
  port is protected (fail-closed -- a set password never starts open). The
  service writes a wayvnc config (`/config/.config/wayvnc/config`, 0600,
  owned by `abc`) with `enable_auth` + `relax_encryption` +
  `allow_broken_crypto` and no TLS credentials, on purpose: with TLS
  credentials present, wayvnc offers VeNCrypt first and noVNC dies in the
  version exchange before any password prompt ("Failed to connect"); without
  them the server offers `[UnixLogon, RA2, ARD(30), VNCAuth(2)]`, measured
  live. noVNC picks Apple-DH (30) and prompts for the password (proven with
  headless Chromium: prompt -> connected -> desktop); classic native clients
  pick DES (2, proven byte-level: wrong password -> `SecurityResult=1`,
  right password -> 0 + ServerInit); macOS Screen Sharing picks ARD.
  `VNC_USER` (default empty) sets the username native VNC clients send; the
  noVNC browser prompt asks for the password only in practice.
- Auth strength: neither path encrypts, and DES uses the first 8 password
  characters. Treat the password as loopback-grade: keep it short (so DES
  and ARD agree) and tunnel over SSH on untrusted networks. Passwords
  containing `=`, `#`, or leading / trailing whitespace are not safe in the
  wayvnc config format -- avoid them.
- Session user: non-root `abc` (uid/gid 911, mapped by `PUID`/`PGID`).
- No WebRTC here: no UDP ports, no STUN/TURN, no single-port-vs-host-network
  tradeoff. One TCP port (6080) carries the desktop over websockets; VNC
  stays container-local. The WS->TCP bridge (`wsbridge`, a small static
  binary) only shovels bytes: it never sees the password, which is
  negotiated end-to-end at the RFB layer between noVNC and wayvnc.
- `wsbridge` hardening: the upgrade pins the served Host against DNS
  rebinding and then checks Origin -- the request `Host` must be a loopback
  spelling (`localhost`, `127.0.0.1`, `::1`, any port -- Docker-mapped and
  ssh-forwarded ports keep working) or be named
  in `WSBRIDGE_ALLOW_HOST` (comma-separated `host[:port]`, empty by default),
  otherwise 403 (`host not allowed (set WSBRIDGE_ALLOW_HOST to allow this
  host)`; the log names the variable once, not per attempt). Requests with
  an allowed Host and no `Origin` header are allowed (non-browser clients such as scripted tests
  send none); requests with an `Origin` are allowed only when it equals the
  request's own Host or is a loopback spelling at the same port, otherwise
  403. Rebound `Host` + matching `Origin` is therefore refused. Plain HTTP
  (the noVNC tree) carries no Host pin on purpose: it holds no credentials
  or state-changing GETs, so serving it to a rebound host is harmless, while
  pinning it would break non-browser health checks without security benefit;
  the WebSocket upgrade is the enforcement point. Access by LAN IP or custom
  hostname needs `-e WSBRIDGE_ALLOW_HOST=host[:port]` (bare hostname allows
  any port). Client frames must be masked and `Sec-WebSocket-Version` must be
  13 (else 426/1002); RSV bits and fragmented/oversized control frames close
  with 1002, unknown opcodes with 1003, over-cap frames/messages (1 MiB
  frame, 4 MiB message) with 1009 -- so a clipboard paste above 1 MiB drops
  the connection and reconnect recovers. All server-to-client writes (data,
  ping, pong, close) share one mutex, so a client ping racing server data
  cannot interleave frame bytes.
  The server sets `ReadHeaderTimeout`, per-connection read (90 s, refreshed
  on every frame received -- ping/pong/continuation included, so server
  pings answered by the browser keep an idle session alive) and write
  (10 s) deadlines with a 30 s ping keepalive (browsers answer automatically,
  so idle noVNC sessions stay up), and caps concurrent proxied connections at
  32 (excess gets 503). Malformed input yields at most one short log line,
  never a stack trace.
- `--shm-size`: not needed. The default is fine; the image does not require
  DRI devices, GPU flags, or privileged mode. Never `--privileged`.
