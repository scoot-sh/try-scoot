# Security

No password is set by default. The documented `docker run` binds the browser
port to host loopback only (`-p 127.0.0.1:6080:6080`); keep it there. To
reach the desktop from elsewhere, tunnel (`ssh -L 6080:localhost:6080`)
rather than publishing the port.

- VNC listener (`VNC_LISTEN`, default `localhost`; `VNC_PORT`, default
  `5900`): loopback only. Native clients can only reach it by publishing it
  or execing into the container network. Publishing it without auth exposes
  an open desktop. Both knobs are honored: wayvnc listens on
  `$VNC_LISTEN:$VNC_PORT` (a `VNC_LISTEN` that already contains a port or
  socket path is used as-is) and the browser path dials
  `localhost:$VNC_PORT`.
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
- `--shm-size`: not needed. The default is fine; the image does not require
  DRI devices, GPU flags, or privileged mode. Never `--privileged`.
