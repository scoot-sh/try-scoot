# Security

No password is set by default. The documented `docker run` binds the browser
port to host loopback only (`-p 127.0.0.1:6080:6080`); keep it there. To
reach the desktop from elsewhere, tunnel (`ssh -L 6080:localhost:6080`)
rather than publishing the port.

- VNC listener (`VNC_LISTEN`, default `localhost`; `VNC_PORT`, default
  `5900`): loopback only. Native clients can only reach it by publishing it
  or execing into the container network. Publishing it without auth exposes
  an open desktop.
- `VNC_PASSWORD`: accepted as an env var but NOT yet wired to wayvnc auth in
  this minimal image. The service logs a warning and starts without auth. Do
  not rely on it. Wiring wayvnc config-file auth (including the RSA key the
  reference image generates) is backlog ticket T2.
- Session user: non-root `abc` (uid/gid 911, mapped by `PUID`/`PGID`).
- No WebRTC here: no UDP ports, no STUN/TURN, no single-port-vs-host-network
  tradeoff. One TCP port (6080) carries the desktop over websockets; VNC
  stays container-local.
- `--shm-size`: recommended `1g` for browser canvas headroom; the image does
  not require DRI devices, GPU flags, or privileged mode. Never `--privileged`.
