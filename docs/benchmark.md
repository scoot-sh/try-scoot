# Benchmark

Measured on the Asahi M2 (aarch64) unless noted; x86_64 comes from CI-built
images where stated.

## Pull size

`docker images ghcr.io/scoot-sh/try-scoot` (compressed pull + unpacked).
Per-step diet numbers live in docs/layers.md; the headline before/after is:

| revision | tarball (pull) | unpacked (`docker export`, flattened) |
|---|---|---|
| `c17611a` (pre-diet) | 624,973,290 B (596.0 MiB) | 2,160,960,931 B (2.013 GiB; `docker image inspect .Size`) |
| this head (`7753542`+) | 185,474,953 B (176.9 MiB) | 593,991,680 B (566.4 MiB) |

## Time-to-first-frame

Seconds from `docker run` to the first decodable frame in a headless browser
(noVNC canvas pixels change), measured with `date +%s.%N` around container
start and the first-frame probe:

| revision | run -> wayvnc capturing | run -> first browser frame |
|---|---|---|
| `c17611a` | 1.0 s (reviewer, M2-class host) | _n/a (implementer 9.0 s incl. browser launch)_ |
| this head | 1.2 s (`date +%s.%N` around `docker run`, 0.2 s poll) | 1.3 s (run -> HTTP 200; headless Chromium painted the desktop in the same session, screenshots) |

Idle with a viewer attached: 0.00% CPU (docker stats), ~49 MiB docker MEM,
NET 78.6 kB rx / 1.75 MB tx over the ~60 s playwright session (frame-flow
witness); idle without viewer: 0.00%, ~43 MiB. The VNC damage model ships
almost nothing on a static screen (same shape as the reference
`image-scoot-vnc` idle win: 0.0% CPU / 0.9 kB/s vs
Selkies 5.0% / 11.1 kB/s holding a static screen -- methodology differs, see
docs/layers.md).

## Input truth (N2)

Established with a scripted RFB client (`rfb-probe.py`, stdlib Python: real
`KeyEvent`/`PointerEvent` frames over TCP, checked against
`scoot msg windows` + `scoot msg screenshot`) driving the wayvnc port
directly, plus headless Chromium through the noVNC path:

- Typing works: plain keys, Shift (`Shift+t` -> `T` in foot, screenshot),
  Ctrl (`Ctrl+l` clears the screen, screenshot). Headless Chromium typed
  `echo hello-browser` into foot and it executed (screenshot).
- Clicks work: click on the unfocused foot flips `focused` in
  `scoot msg windows`; click on bar workspace `2` switches to the empty
  workspace (screenshot: windows gone, cursor on `2`).
- Compositor chords over VNC never fire: `Alt+Return`, `Alt+t`, `Alt+d`,
  `Super+Return`, via raw RFB and via headless Chromium (`Alt+Enter`
  screenshot byte-identical, window count unchanged). This is **not** a test
  artifact and not an image defect: scoot's `virtual_input` module delivers
  virtual-keyboard input through a forward-only filter, so remote keys reach
  clients but never run keybindings ("window management stays local" --
  quoted from `crates/scoot/src/compositor/virtual_input.rs` at the locked
  scoot rev `74358ec`). Nothing in this packaging repo can change that; the
  `VNC_KEYBOARD=us` knob was also tried and changes nothing.
- The binds themselves are live and functional: `scoot msg binds` lists
  `alt+Return`/`alt+t`/`alt+d`/`alt+q` (+ super mirrors) from config, and
  `scoot msg key alt+Return` spawns a terminal (window count 1 -> 2).
  Agents drive chords via `scoot msg key` / `scoot msg pointer` instead.
- README advertises exactly this: typing + pointing over VNC, chords via
  `scoot msg`. Browser-side note: some browsers additionally grab
  Alt/Super, but the chords would not fire even if they arrived.

## Reference deltas

Closure size and idle CPU/RAM vs `image-scoot-dev` / `image-scoot-vnc` in
`yackey-labs/nixos-webtop`: not measured byte-for-byte (different nixpkgs
pins -> different store graphs). Expected direction: ours omits chromium,
nautilus, helix/btop/lazygit/starship, the Selkies web stack, nginx, and the
pulse daemon.
