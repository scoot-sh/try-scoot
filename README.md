```sh
docker run --rm -p 127.0.0.1:6080:6080 ghcr.io/scoot-sh/try-scoot
# open http://localhost:6080/ -- no client install
```

# try-scoot

The smallest fast way to try scoot: a lightweight desktop running the scoot
compositor from the scoot flake, in your browser. No GPU needed (scoot's
pixman path, software capture); no client install.

What drove scoot: a no-GPU webtop you can open in a browser, and a desktop an
agent can drive as easily as a person (scoot's control socket). This image is
the "try it" visit: a terminal, the launcher, the bar, and a palette-color
look. Nothing else.

## Run

```sh
docker run --rm -p 127.0.0.1:6080:6080 --shm-size=1g -v try-scoot-config:/config ghcr.io/scoot-sh/try-scoot
```

Open `http://localhost:6080/`. The page forwards to the noVNC client
(autoconnect, scale to window, reconnect). Native VNC clients use port 5900,
which stays on container loopback unless you publish it.

Size it with `VNC_WIDTH`/`VNC_HEIGHT` (default `1280x800`). `VNC_FPS`
(default `30`) caps the capture rate. `VNC_KEYBOARD` picks a wayvnc keyboard
layout. `VNC_LISTEN` (default `localhost`) and `VNC_PORT` (default `5900`)
control the VNC listener; `NOVNC_LISTEN` (default `0.0.0.0`) and
`NOVNC_PORT` (default `6080`) control the browser port.

Keys: `Alt+Return` terminal, `Alt+d` launcher, `Alt+q` close,
`Alt+h/j/k/l` move focus. `Super` doubles every `Alt` bind for use inside a
terminal (readline owns `Alt+b`/`Alt+d`).

## Ports and security

No password is set by default, so keep the browser port on loopback as in
the one-liner above (`-p 127.0.0.1:6080:6080`). To reach it from elsewhere,
tunnel over `ssh -L 6080:localhost:6080`. `VNC_PASSWORD` is accepted but not
yet wired to wayvnc auth in this minimal image: setting it alone does not
protect the port, so treat an image with a published port as an open desktop
until password auth lands (see docs/security.md).

The container runs the session as non-root user `abc` (uid 911). The VNC
port binds loopback only by default; the browser port is the only one the
one-liner publishes. WebRTC is not used here, so there are no UDP ports,
STUN/TURN servers, or host-networking needs: one TCP port carries the whole
desktop. `--shm-size=1g` is recommended for the browser-side canvas; the
image itself needs no shared memory beyond the default, but some runtimes
size `/dev/shm` small.

## Build

With Nix on Linux:

```sh
nix build .#image-try-scoot && docker load < result
```

Images are `dockerTools.buildLayeredImage` outputs for `x86_64-linux` and
`aarch64-linux`. `nix flake check` runs the look-hygiene check (no
third-party images). See docs/ for layers, measurements, and the Selkies
packaging decision.

## How it relates to scoot and to nixos-webtop

scoot (`github:scoot-sh/scoot`) ships the compositor, `scootbar`, and
`scootbg`; this image consumes that flake (`inputs.scoot`, nixpkgs followed
so the image carries one stack) and runs headless scoot directly, captured
by wayvnc. The desktop profile's shape (bar, wallpaper, launcher, terminal)
mirrors `programs.scoot.desktop`, but the container does not run NixOS
modules: it seeds plain config files.

`yackey-labs/nixos-webtop` is the inspiration, not the source: it taught us
the pieces (flake-built images, headless scoot + wayvnc + noVNC, input and
look seeding), but every file here is written fresh for this repo under MIT.
No browser, file manager, or dev tools ship here beyond the "try it" visit.
