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
docker run --rm -p 127.0.0.1:6080:6080 ghcr.io/scoot-sh/try-scoot
```

Open `http://localhost:6080/`. The page forwards to the noVNC client
(autoconnect, scale to window, reconnect). Native VNC clients use port 5900,
which binds container loopback by default: publishing it with
`-p 5900:5900` alone is not enough (the listener stays on loopback, so the
mapping accepts then EOFs) -- add `-e VNC_LISTEN=0.0.0.0` to reach it from
outside the container.

The one-liner above is the whole story: the image needs no `--shm-size`
(the browser-side canvas lives in the *host* browser, and the container runs
fine with the runtime default) and no named volume (a `/config` volume only
matters if you want your config edits to survive `--rm`;
add `-v try-scoot-config:/config` for that).

Size it with `VNC_WIDTH`/`VNC_HEIGHT` (default `1280x800`). `VNC_FPS`
(default `30`) caps the capture rate. `VNC_KEYBOARD` picks a wayvnc keyboard
layout. `VNC_LISTEN` (default `localhost`) and `VNC_PORT` (default `5900`)
control the VNC listener -- both are honored: the wayvnc service listens on
`$VNC_LISTEN:$VNC_PORT` (a bare host gets `:$VNC_PORT` appended) and the
in-container noVNC proxy dials the same target (`0.0.0.0` maps back to
`localhost`; a `VNC_LISTEN` holding a unix socket path is unsupported and
the browser service refuses to start loudly rather than dialing the wrong
port). `NOVNC_LISTEN`
(default `0.0.0.0`) and `NOVNC_PORT` (default `6080`) control the browser
port.

Keys: `Alt+Return` / `Super+Return` / `Alt+t` / `Super+t` terminal, `Alt+d` /
`Super+d` launcher, `Alt+q` / `Super+q` close, `Alt+h` / `Alt+l` (and the
`Super` mirrors) move focus between columns. `Super` doubles every `Alt` bind
because some browsers/OSes grab `Alt` chords (and some grab `Super`/Cmd) --
inside a terminal prefer the `Super` binds (readline owns `Alt+d` and friends).

Remote chords fire: the image sets `[virtual_input] binds = true` (with
`enabled = true`, restart-only -- see scoot `remote-desktop.md`), so
virtual-keyboard keys run compositor binds, matched by translated seat
keysym. Proven live with a scripted RFB client driving the wayvnc port and
headless Chromium through noVNC: `Alt+Return` 1 -> 2 windows, `Super+Return`
2 -> 3, `Alt+d` respawns fuzzel after a kill, `Alt+h` / `Alt+l` move focus
(RFB 3 -> 2 -> 3; browser 4 -> 1 -> 2), typing still works (RFB
`touch /tmp/vnctypeok` creates the file; browser `echo hello-browser`
types). `scoot msg locked` was `false` for the proof; while locked, virtual
motion/buttons/keys (including binds) are dropped and can never unlock.
Browser-side limits remain: a browser/OS that grabs a chord never sends it,
so click the canvas first and try the `Super` mirror when `Alt` is eaten.
The fallback that always works is the control socket from inside the
container: `docker exec -u abc -e XDG_RUNTIME_DIR=/run/user/911 <c> scoot msg key alt+Return`
(and `scoot msg pointer`). Details and evidence in docs/benchmark.md.

## Ports and security

No password is set by default, so keep the browser port on loopback as in
the one-liner above (`-p 127.0.0.1:6080:6080`). To reach it from elsewhere,
tunnel over `ssh -L 6080:localhost:6080` (the tunnel keeps `Host:
localhost:6080`, so it passes the Host pin).

The WebSocket upgrade pins the served Host against DNS rebinding: only
`localhost`, `127.0.0.1`, or `[::1]` (any port, so Docker `-p 6081:6080`
mappings and `ssh -L` local ports keep working) connect by default.
Opening the desktop by LAN IP or another hostname needs
`WSBRIDGE_ALLOW_HOST` (comma-separated `host[:port]`, empty by default):

```sh
docker run --rm -p 6080:6080 -e WSBRIDGE_ALLOW_HOST=192.168.1.5:6080 ghcr.io/scoot-sh/try-scoot
# or -e WSBRIDGE_ALLOW_HOST=myhost for any port / multiple: -e WSBRIDGE_ALLOW_HOST=myhost,192.168.1.5:6080
```

A bare hostname allows any port; a `host:port` entry requires that exact
port. A non-default browser port (`-e NOVNC_PORT=6081 -p 127.0.0.1:6081:6081`)
keeps working on `localhost` because the pin exempts loopback names at any port. Without
a listing the upgrade gets 403 (`host not allowed (set WSBRIDGE_ALLOW_HOST
to allow this host)`) and the log names the variable once.

`VNC_PASSWORD` enables wayvnc password auth (fail-closed: setting it always
protects the port, never starts open). With `[virtual_input] binds = true`,
any remote client that can reach the VNC port can now also spawn programs and
run compositor actions through binds (a terminal, the launcher) -- not just
type and click -- so treat VNC reach as shell-equivalent and keep it on
loopback or behind `ssh -L` unless the remote user owns the session. The
service writes a wayvnc config
with password auth; noVNC in a browser prompts for the password (proven
end-to-end with headless Chromium: prompt -> desktop), classic native
clients use DES, macOS Screen Sharing uses Apple-DH. Deliberately no TLS
keys are configured: wayvnc's VeNCrypt handshake is unusable by noVNC (it
fails the version exchange before any prompt), so TLS credentials would
protect native clients while bricking the browser path -- see
docs/security.md for the measured handshake table. Neither the browser nor
the DES path encrypts, and DES uses the first 8 password characters, so keep
passwords short and tunnel over SSH on untrusted networks. `VNC_USER`
(default empty) sets the wayvnc username; the browser prompt only asks for
the password in practice. Full posture in docs/security.md.

Clipboard paste above 1 MiB drops the connection (1 MiB frame cap, close
1009); reconnect recovers and typical pastes (KBs) are unaffected.

The container runs the session as non-root user `abc` (uid 911). The VNC
port binds loopback only by default; the browser port is the only one the
one-liner publishes. The one-liner's trust posture is unchanged by `binds`:
loopback-only default with an optional `VNC_PASSWORD` (loopback-grade, tunnel
over SSH on untrusted nets) -- what changes is only what VNC reach implies
once it happens (binds can now spawn), which is why the loopback default
matters more, not less. WebRTC is not used here, so there are no UDP ports,
STUN/TURN servers, or host-networking needs: one TCP port carries the whole
desktop.

## Build

With Nix on Linux:

```sh
nix build .#image-try-scoot && docker load < result
```

Images are `dockerTools.buildLayeredImage` outputs for `x86_64-linux` and
`aarch64-linux`. `nix flake check` runs the look-hygiene check (no
third-party images). See docs/ for layers, measurements, and the Selkies
packaging decision.

CI pushes per-arch tags on every `main` push (`:x86_64-linux`,
`:aarch64-linux`, combined into `:latest`) and `pr-<N>-<shortsha>-<system>`
per-arch tags on pull requests from this repo, so the `ghcr.io/…` one-liner is
testable before merge. Note: this repo is private for now, so the GHCR
package is private by default -- the maintainer must flip package visibility
to public for "anyone can paste". Builds read the `scoot-sh` Cachix cache
(read-only); pushing to it is a maintainer job needing a `CACHIX_AUTH_TOKEN`
secret, which is deliberately not wired into CI here.

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
