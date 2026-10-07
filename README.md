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
which stays on container loopback unless you publish it.

The one-liner above is the whole story: the image needs no `--shm-size`
(the browser-side canvas lives in the *host* browser, and the container runs
fine with the runtime default) and no named volume (a `/config` volume only
matters if you want your edits and the wayvnc TLS/RSA keys to survive
`--rm`; add `-v try-scoot-config:/config` for that).

Size it with `VNC_WIDTH`/`VNC_HEIGHT` (default `1280x800`). `VNC_FPS`
(default `30`) caps the capture rate. `VNC_KEYBOARD` picks a wayvnc keyboard
layout. `VNC_LISTEN` (default `localhost`) and `VNC_PORT` (default `5900`)
control the VNC listener -- both are honored: the wayvnc service listens on
`$VNC_LISTEN:$VNC_PORT` and the in-container noVNC proxy dials
`localhost:$VNC_PORT`, so the browser path tracks the knob. `NOVNC_LISTEN`
(default `0.0.0.0`) and `NOVNC_PORT` (default `6080`) control the browser
port.

Keys: `Alt+Return` / `Super+Return` / `Alt+t` / `Super+t` terminal, `Alt+d` /
`Super+d` launcher, `Alt+q` / `Super+q` close, `Alt+h` / `Alt+l` (and the
`Super` mirrors) move focus between columns. `Super` doubles every `Alt` bind
because some browsers grab `Alt` chords -- inside a terminal prefer the
`Super` binds (readline owns `Alt+d` and friends).

Over VNC (browser or native client) only typing and pointing work: scoot
deliberately never runs keybindings from virtual-keyboard input
(forward-only filter in its `virtual_input` module -- a remote layout can
disagree with the seat layout about what a key *is*, so intercepting would
misbehave; window management stays local). Proven live with a scripted RFB
client: plain typing, Shift/Ctrl chords, window-focus clicks and bar
workspace clicks all arrive; `Alt+Return`/`Alt+d`/`Super+t` never fire, in a
real headless browser identically. The binds themselves are registered and
functional -- `scoot msg key alt+Return` from inside the container spawns a
terminal -- so agents drive chords over `scoot msg key` / `scoot msg pointer`
instead. Details and evidence in docs/benchmark.md.

## Ports and security

No password is set by default, so keep the browser port on loopback as in
the one-liner above (`-p 127.0.0.1:6080:6080`). To reach it from elsewhere,
tunnel over `ssh -L 6080:localhost:6080`.

`VNC_PASSWORD` enables wayvnc password auth (fail-closed: setting it always
protects the port, never starts open). The service writes a wayvnc config
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

The container runs the session as non-root user `abc` (uid 911). The VNC
port binds loopback only by default; the browser port is the only one the
one-liner publishes. WebRTC is not used here, so there are no UDP ports,
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
`:aarch64-linux`, combined into `:latest`) and `pr-<N>-<shortsha>` per-arch
tags on pull requests from this repo, so the `ghcr.io/…` one-liner is
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
