# Benchmark

Measured on the Asahi M2 (aarch64) unless noted; x86_64 comes from CI-built
images where stated.

## Pull size

Unpacked bytes throughout these docs mean `docker export` of the loaded
image (flattened filesystem bytes). Per-step diet numbers live in
docs/layers.md; the headline before/after is:

| revision | tarball (pull) | unpacked (`docker export`, flattened) |
|---|---|---|
| `c17611a` (pre-diet) | 624,973,290 B (596.0 MiB) | 2,160,960,931 B (2.013 GiB) |
| this head (scoot `b11eb8c`, `binds = true`) | 185,486,893 B (176.9 MiB) | 595,570,688 B (568.0 MiB) |

No pull regression from 177 MiB (+11,940 B tarball, +1.6 MB unpacked --
scoot version drift, same diet).

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
witness); idle without viewer: 0.00%, ~43 MiB (re-measured this head fresh:
0.00%, 37.3 MiB, 1 window; 5 windows + viewer attached: 0.00%, 92 MiB).
The VNC damage model ships
almost nothing on a static screen (same shape as the reference
`image-scoot-vnc` idle win: 0.0% CPU / 0.9 kB/s vs
Selkies 5.0% / 11.1 kB/s holding a static screen -- methodology differs, see
docs/layers.md).

## Input truth (binds ON)

With scoot `b11eb8c` (contains #494) and the image's `[virtual_input]
enabled = true` + `binds = true` (restart-only), remote chords run binds.
Established with a scripted RFB client (`rfb-probe.py`, stdlib Python: real
`KeyEvent`/`PointerEvent` frames over TCP, checked against
`scoot msg windows` + `scoot msg screenshot`) driving the wayvnc port
directly, plus headless Chromium (Google Chrome 154, playwright-core)
through the noVNC path. `scoot msg locked` was `false` throughout; while
locked, virtual input (including binds) is dropped and can never unlock.

- Typing works: plain keys, Shift (`Shift+t` -> `T` in foot, screenshot),
  Ctrl (`Ctrl+l` clears the screen, screenshot) from the prior round still
  hold; this round RFB `touch /tmp/vnctypeok` + Return creates the file, and
  headless Chromium typed `echo hello-browser` into foot (screenshots
  `brow-typed.png`, `brow-desktop.png`).
- Clicks work: click on the unfocused foot flips `focused` in
  `scoot msg windows`; click on bar workspace `2` switches to the empty
  workspace (prior-round screenshots, unchanged behavior).
- Compositor chords over VNC now fire (was: never, under scoot `74358ec`'s
  forward-only `virtual_input` filter). Raw RFB: `Alt+Return` 1 -> 2 windows,
  `Super+Return` 2 -> 3, `Alt+d` respawns fuzzel after `pkill` (new pid),
  `Alt+h` 3 -> 2 focused then `Alt+l` 2 -> 3. Headless browser:
  `Alt+Enter` + `Meta+Enter` (Super) 3 -> 5 windows, `Alt+d` respawns fuzzel
  after a kill, `Alt+h` 4 -> 1 then `Alt+l` 1 -> 2 focused (all via
  `scoot msg windows` + `pgrep fuzzel` + screenshots `brow-altenter.png`,
  `brow-superenter.png`, `brow2-altd2.png`, `h-only.png`, `l-only.png`).
  Status stayed `Connected (unencrypted) to WayVNC`.
- The binds themselves are live: `scoot msg binds` lists `alt+Return` /
  `alt+d` / `alt+q` (+ super mirrors) from config, and
  `scoot msg key alt+Return` still spawns a terminal. Agents can use either
  path; `scoot msg key` / `scoot msg pointer` remains the fallback that never
  depends on browser focus.
- README advertises exactly this: chords fire over VNC, with the
  browser-side caveat (some browsers/OSes grab Alt/Super/Cmd -- click the
  canvas first, try the `Super` mirror) and the `scoot msg key` fallback.

## Reference deltas

Closure size and idle CPU/RAM vs `image-scoot-dev` / `image-scoot-vnc` in
`yackey-labs/nixos-webtop`: not measured byte-for-byte (different nixpkgs
pins -> different store graphs). Expected direction: ours omits chromium,
nautilus, helix/btop/lazygit/starship, the Selkies web stack, nginx, and the
pulse daemon.
