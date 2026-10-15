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
| ginger-night default (scoot `134e39a`) | 186,881,227 B (178.2 MiB) | 598,816,768 B (571.1 MiB) |
| this head, measured on the branch (lean baseline rebuilt: scoot `722afd2`) | 187,027,379 B (178.4 MiB) | 599,079,936 B (571.3 MiB) |
| this head (show-it-off: fonts, bar modules, bash+starship, nvim+btop) | 243,967,344 B (232.7 MiB) | 728,530,944 B (694.8 MiB) |
| this head (scoot `v0.2.1` / `e5b9dd6`: one default build, Mocu cursor) | 294,188,906 B (280.6 MiB) | 880,126,976 B (839.4 MiB) |

Pull +1,394,334 B (+0.75%) for the look: the 926,588 B wallpaper (already
optimally compressed upstream, so it rides almost byte-for-byte) plus the
Mocu cursor theme (~1.1 MB NAR, both Mocu white and Mocu-Black) and larger configs. Unpacked
+3.2 MB for the same reason. No diet regression: L0/L1 still build the old
solid-plum path byte-identical in shape.

Show-it-off delta, pull +56,934,505 B (+30.4%), unpacked +129,449,984 B,
marginal NAR 127,347,152 B across 22 new store paths (same method as the
diet table: closure of the new top-level packages minus what the image
already had). Biggest pieces: FiraCode Nerd Font 48,987,800 B (the look's
terminal face; one output, all weights), neovim-unwrapped 34,067,320 B
plus its tree-sitter grammars/luajit/libuv (~17 MB more; the wrapped
`neovim` would add ~190 MB of perl/python providers on top),
starship 14,678,024 B, DroidSansM Nerd Font Propo 7,359,008 B (the bar's
icons), btop 2,123,488 B, bash-completion 1,271,696 B. Per-step table in
docs/layers.md. Still 61% below the pre-diet pull.

scoot v0.2.1 bump delta (same-box rebuilds on the dev VM, aarch64; the old
rev rebuilt at `20bca8a` gives 243,961,822 B pull, within 62 B of the M2
number above, so cross-builder tarballs compare): pull 243,961,822 B ->
294,188,906 B (+50,227,084 B, +20.6%), unpacked 728,529,920 B ->
880,126,976 B (+151,597,056 B, +20.8%). Marginal root-env NAR +149,535,112 B
(713,050,040 B -> 862,585,152 B), split as: scoot bump +151,934,488 B (the
scoot package closure grows 129,404,608 B -> 402,527,968 B NAR: the single
0.2.1 build carries the Xwayland server on its `PATH` plus the compiled-in
xwayland/gpu-scanout code, per scoot #585/#588; most of that closure's
libraries were already in the image, so the pull sees ~50 MB not ~150 MB)
and cursor swap -2,399,376 B (vanilla-dmz 3,690,808 B NAR -> mocu 1,113,328 B;
only Mocu white ships -- `buildEnv` links the package's `out` output, the
`black` output with Mocu-Black stays out -- and the look's
`cursor_theme`/`XCURSOR_THEME` now resolve to `Mocu`, verified in the built
skeleton). L0/L1 diet shape intact at the new rev: L0 279,484,262 B
(266.5 MiB), L1 293,156,814 B (279.6 MiB); still 53% below the pre-diet pull.

## Time-to-first-frame

Seconds from `docker run` to the first decodable frame in a headless browser
(noVNC canvas pixels change), measured with `date +%s.%N` around container
start and the first-frame probe:

| revision | run -> wayvnc capturing | run -> first browser frame |
|---|---|---|
| `c17611a` | 1.0 s (reviewer, M2-class host) | _n/a (implementer 9.0 s incl. browser launch)_ |
| prior head | 1.2 s (`date +%s.%N` around `docker run`, 0.2 s poll) | 1.3 s (run -> HTTP 200; headless Chromium painted the desktop in the same session, screenshots) |
| ginger-night | 0.88 s (run -> `capturing` in `docker logs`, 0.2 s poll) | 0.91 s (run -> HTTP 200; canvas painted at +0.6 s in the same session, screenshots `docs/ginger-night-default.png`) |
| lean baseline rebuilt (this branch) | 0.83 s | 0.84 s (same method, 0.2 s poll) |
| this head (two first-run columns) | 0.91 s | 0.92 s (screenshot `docs/show-it-off.png`) |
| this head (scoot v0.2.1, re-measured M2, same method) | 0.91 s | 0.92 s |

One extra foot costs ~0.1 s. Idle, re-measured this round (no viewer, fresh
container, 30 s settle per state, 3 runs; method below):

| state | CPU (`docker stats`) | MEM (`docker stats`) | `memory.current` | anon / file |
|---|---|---|---|---|
| lean baseline (1 sh terminal) | 0.00% | 44.9 MiB | _n/a (prior round)_ | _n/a_ |
| this head, static desktop (no windows) | 0.00% | 41.0-43.5 MiB | 45.1-48.5 MB | 29.0 / 6.4-7.3 MB |
| this head, bash terminal only | 0.00% | 49.3-52.7 MiB | 53.6-58.1 MB | 34.0 / 10.1-11.0 MB |
| this head at scoot v0.2.1, bash only (same method) | 0.00% | 52.1 MiB | 53.8 MB | _n/a_ |
| this head at scoot v0.2.1, static desktop (same method) | 0.00% | 40.1 MiB | 41.9 MB | _n/a_ |
| this head, first-run (bash + live btop) | 1.20-1.23% | 58.7-59.6 MiB | 62.5-66.3 MB | 37.7-38.6 / 13.8-14.6 MB |
| this head at scoot v0.2.1 (fresh container, 30 s settle, same method) | 1.5-3.1% | 59.7-62.3 MiB | 61.4 MB | _n/a_ |

Method: per state, after a 30 s settle with no viewer attached, read the
container cgroup's `memory.current` (total bytes charged) plus
`memory.stat` (`anon` = anonymous process memory incl. shm, `file` = page
cache incl. tmpfs, `kernel` ≈ 6.5-9.2 MB shown separately), the
in-container RSS sum (`ps -eo rss`), and `docker stats` MEM for comparison.
Exact commands: `ID=$(docker inspect -f '{{.Id}}' <c>)`,
`CG=/sys/fs/cgroup/system.slice/docker-$ID.scope`,
`cat $CG/memory.current`, `grep -E '^(anon|file|kernel|shmem) ' $CG/memory.stat`,
`docker stats --no-stream <c>`,
`docker exec <c> ps -eo rss --no-headers | awk '{s+=$1} END {print s}'`.
States: first-run as autostarted, then bash-only after `pkill -x btop`,
then static after `pkill -x foot` (bar/bg/proxy remain), each re-settled
30 s. Full per-run numbers are in the fix report.

Why the old ~60 MiB "did not reproduce" at 234 MiB: `docker stats` MEM is
`memory.current` minus reclaimable file cache, and file-cache residency
depends on what the container has done. A fresh settled container
reproduces ~59-60 MiB three times running (this round and the author's);
a container that has served viewer sessions and screenshots accumulates
page cache and shm buffers (a used container here read `current` 77.7 MB
vs 59.6-66.3 MB fresh), and a single `docker stats` sample from such a
container reads higher. Under memory pressure the file share is
reclaimable; for comparable numbers use a fresh container, 30 s settle,
no viewer. The in-container RSS sum (~156 MiB) overcounts: every process
maps the same Nix-store libraries and fonts, so shared pages are counted
once per process; `anon` (~38 MB first-run) is the unshared process
memory. README now carries the fresh-settled ranges above, not the old
single samples (static was ~52 MiB, bash-only ~63 MiB).

The btop column redraws every 1.5 s and VNC ships the damage when a viewer
is attached (prior rounds: 2-4% with a viewer painting; 1.2% with no
viewer, this round): any animation costs this, not btop specifically.
Close it and idle is 0% again.

Bar CPU, before/after (scootbar utime+stime jiffies delta over 60 s idle,
`/proc` reads from inside the container, 8 CPUs, USER_HZ=100): lean
baseline 0.000% (0 jiffies), this head with load+cpu helpers firing every
10 s 0.002% (1 jiffy: 100 x 1 / (60 x 100 x 8)). One 10 ms tick in a
minute across 8 CPUs is scheduler granularity, not a polling storm: each
helper wake is microseconds; the bar itself wakes only when a line
arrives.

Idle with a viewer attached: 0.00% CPU (docker stats), ~49 MiB docker MEM
(prior head; NET 78.6 kB rx / 1.75 MB tx over the ~60 s playwright session);
idle without viewer this head: 0.00% static / bash-only, ~1.2% first-run
(table above; wallpaper decode plus cursor theme and translucent
bar/terminals; CPU still 0% without the live column -- the damage model
ships nothing static). Time to first frame unchanged
(~1 s).
The VNC damage model ships
almost nothing on a static screen (same shape as the reference
`image-scoot-vnc` idle win: 0.0% CPU / 0.9 kB/s vs
Selkies 5.0% / 11.1 kB/s holding a static screen -- methodology differs, see
docs/layers.md).

## Pointer visibility (invisible-mouse fix)

User report: no mouse pointer visible in the browser. Root cause, each link
measured: without `wayvnc -r`, scoot's headless screencopy frames carry no
cursor (the ext-image-copy-capture session defaults to `paint_cursors=false`,
so frames are cursorless by request), and scoot refuses the separate
pointer-cursor session outright, so wayvnc sends zero cursor-shape rects
(raw RFB probe over the noVNC websocket: 0 cursor pseudo-encoding rects in
8 s, before and after). noVNC then hides the local pointer: on connect it
calls `_refreshCursor()` with the default `none` cursor, and
`Cursor.clear()` sets `canvas.style.cursor = 'none'`.

Fix shipped, in two layers. (1) The image now runs `wayvnc -r`
(`rootfs/s6/service/wayvnc/run`): with `PAINT_CURSORS` requested, scoot
re-renders the pointer into each capture, so the real Mocu arrow
rides in the frame pixels. Verified live: stable raw-RFB frames at two
pointer positions are byte-identical without `-r` (modulo the bar's live
modules) and differ with `-r`; a 30x30 patch at the pointer shows the
bright arrow where the pointer sits and background where it does not; a
headless-Chrome (Google Chrome 153, playwright-core) screenshot of the
noVNC page shows the real arrow. An earlier throwaway test that reported
"`-r` changes nothing" compared frames without settling after the pointer
move (captures taken within ~1 s of a move catch a full-screen transient)
or at a single pointer position -- re-tested with 5 s settles and control
pairs, the arrow is reliably there. (2) The `show_dot=true` redirect param
stays: no cursor *shape* is ever sent (the pointer-cursor refusal is
unchanged), so the dot remains the local-cursor cover at the hotspot; a
`cursor-dot-fallback` flake check pins the param. The
`look-no-third-party` check still passes. Cost of `-r`: pointer moves
damage the frame (as any motion does); static idle is unaffected.

Upstream repro for scoot (not filed; do not open upstream issues from
here): run this image, connect noVNC, move the mouse -- no pointer;
`scoot msg screenshot` draws one (IPC screenshots re-render the cursor
on demand) while screencopy frames never contain it. Proper fix belongs
in scoot's headless/nested capture (honor the screencopy cursor request
or advertise the cursor to VNC backends).

## Selkies variant (`:selkies`)

Same method, Mac Docker Desktop (arm64) runs of M2-built images; full
tables in docs/selkies.md. Ginger-night head (scoot `134e39a`): full
515,831,613 B (492.0 MiB), unpacked 1,753,213,440 B (1.633 GiB). This head
(same apps+fonts as the default tag): full 572,805,816 B (546.3 MiB),
unpacked 1,882,613,760 B (1.753 GiB) -- +56,974,203 B (+54.3 MiB) pull /
+129,400,320 B (+123.4 MiB) unpacked, the same delta as the default tag. Default tag this head 243,967,344 B /
728,530,944 B. At scoot v0.2.1 (this bump, dev VM build + M2 export):
full 622,264,070 B (593.4 MiB), unpacked 2,030,473,728 B (1.891 GiB) --
+49,458,254 B (+8.6%) pull / +147,859,968 B unpacked over the show-it-off
head, the same scoot-bump delta as the default tag. Run to
stream (full tag): HTTP 200 at 1.05 s (prior round), first client settings
applied (1280x800 h264enc) at 1.6 s, painted desktop in a persistent
headless-Chromium connection (screenshots `docs/ginger-night-selkies.png`,
stream up at +0.7 s this head). Idle, re-measured this head without a
viewer: 0.20% / 140.5 MiB (prior 0.19-0.27% / ~119 MiB); with a viewer
attached and actively streaming the prior round's 27-48% / ~143 MiB still
describes the software-x264 cost (plus a few percent for the live btop
column); L0 0.18% / 71.7 MiB (prior round). Nested smoke this head: same
two first-run columns and live bar modules over `scoot msg screenshot`
(1024x768: the btop column shows btop's own too-small notice below 60
columns -- widen the viewer and it renders; the prompt cwd fix,
`cd "${HOME:-/config}"` in the selkies `de` service, verified: `~`).

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
