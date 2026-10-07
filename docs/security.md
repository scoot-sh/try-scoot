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
- `wsbridge` hardening: the upgrade carries a same-origin check -- requests
  with no `Origin` header are allowed (non-browser clients such as scripted
  tests send none); requests with an `Origin` are allowed only when it equals
  the request's own Host or is a loopback spelling (`localhost`,
  `127.0.0.1`, `::1`) at the same port, otherwise 403. Client frames must be
  masked and `Sec-WebSocket-Version` must be 13 (else 426/1002); RSV bits and
  fragmented/oversized control frames close with 1002, unknown opcodes with
  1003, over-cap frames/messages (1 MiB frame, 4 MiB message) with 1009.
  The server sets `ReadHeaderTimeout`, per-connection read (90 s, refreshed
  on every frame) and write (10 s) deadlines with a 30 s ping keepalive
  (browsers answer automatically, so idle noVNC sessions stay up), and caps
  concurrent proxied connections at 32 (excess gets 503). Malformed input
  yields at most one short log line, never a stack trace.
- `--shm-size`: not needed. The default is fine; the image does not require
  DRI devices, GPU flags, or privileged mode. Never `--privileged`.
