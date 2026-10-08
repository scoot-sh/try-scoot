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
| prior head (scoot `b11eb8c`, `binds = true`) | 185,486,893 B (176.9 MiB) | 595,570,688 B (568.0 MiB) |
| this head (scoot `134e39a`, ginger-night default) | 186,881,227 B (178.2 MiB) | 598,816,768 B (571.1 MiB) |

Pull +1,394,334 B (+0.75%) for the look: the 926,588 B wallpaper (already
optimally compressed upstream, so it rides almost byte-for-byte) plus the
Vanilla-DMZ cursor theme (~3.3 MB unpacked) and larger configs. Unpacked
+3.2 MB for the same reason. No diet regression: L0/L1 still build the old
solid-plum path byte-identical in shape.

## Time-to-first-frame

Seconds from `docker run` to the first decodable frame in a headless browser
(noVNC canvas pixels change), measured with `date +%s.%N` around container
start and the first-frame probe:

| revision | run -> wayvnc capturing | run -> first browser frame |
|---|---|---|
| `c17611a` | 1.0 s (reviewer, M2-class host) | _n/a (implementer 9.0 s incl. browser launch)_ |
| prior head | 1.2 s (`date +%s.%N` around `docker run`, 0.2 s poll) | 1.3 s (run -> HTTP 200; headless Chromium painted the desktop in the same session, screenshots) |
| this head (ginger-night) | 0.88 s (run -> `capturing` in `docker logs`, 0.2 s poll) | 0.91 s (run -> HTTP 200; canvas painted at +0.6 s in the same session, screenshots `docs/ginger-night-default.png`) |

Idle with a viewer attached: 0.00% CPU (docker stats), ~49 MiB docker MEM
(prior head; NET 78.6 kB rx / 1.75 MB tx over the ~60 s playwright session);
idle without viewer this head: 0.00%, 59.9 MiB, 2 windows (wallpaper decode
~8 MB in scootbg plus cursor theme and translucent bar/terminals; CPU still
0% -- the damage model ships nothing static). Time to first frame unchanged
(~1 s).
The VNC damage model ships
almost nothing on a static screen (same shape as the reference
`image-scoot-vnc` idle win: 0.0% CPU / 0.9 kB/s vs
Selkies 5.0% / 11.1 kB/s holding a static screen -- methodology differs, see
docs/layers.md).

## Selkies variant (`:selkies`)

Same method, Mac Docker Desktop (arm64) runs of M2-built images; full
tables in docs/selkies.md. This head (ginger-night, scoot `134e39a`): full
515,831,613 B (492.0 MiB) vs prior 514,438,714 B (+1.39 MB, the same look
delta as the default tag); unpacked 1,753,213,440 B vs 1,748,387,328 B
(+4.8 MB). Default tag this head 186,881,227 B / 598,816,768 B. Run to
stream (full tag): HTTP 200 at 1.05 s (prior round), first client settings
applied (1280x800 h264enc) at 1.6 s, painted desktop in a persistent
headless-Chromium connection (screenshots `docs/ginger-night-selkies.png`,
stream up at +0.7 s this head). Idle: full 0.19-0.27% / ~119 MiB without a viewer,
27-48% / ~143 MiB with a viewer attached and actively streaming
(software x264 FullFrame 60 fps -- the old 0.19%-with-viewer claim came
from a backgrounded client); L0 0.18% / 71.7 MiB (prior round).

## Input truth (binds ON)

With scoot `134e39a` (contains #494 and the ginger-night look #506) and the image's `[virtual_input]
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
