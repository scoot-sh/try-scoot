# Layers

- L0 `image-l0`: headless scoot + foot, wayvnc + noVNC. No bar, no wallpaper
  daemon, no launcher. The smallest thing that streams.
- L1 `image-l1`: L0 + `scootbar` + `scootbg` + `fuzzel` (the desktop profile
  packages from the scoot flake).
- final `image-try-scoot`: L1 + the default look (palette-color solid
  wallpaper generated at build time, themed foot/bar configs).

## Diet (reviewer §5 plan, implemented this round)

Unpacked sizes via `nix path-info -s`; chains via `nix why-depends`.
Compressed-savings figures are measured tarball deltas where built, marked ~
where estimated from the overall ratio (≈3.6x pre-diet).

| step | cut | unpacked | pull | kept? |
|---|---|---|---|---|
| 0 | baseline `c17611a` | 2.013 GiB | 596.0 MiB | -- |
| 1 | drop `mesa` + `libGL` + `libglvnd` (keep `libgbm`: wayvnc links `libgbm.so.1`, verified via `ldd`; foot links no GL at all) | _proof_ | _proof_ | _proof_ |
| 2 | replace python `websockify` + numpy with `wsbridge` (small static Go binary, stdlib only) | _proof_ | _proof_ | _proof_ |
| 3 | single-locale glibc archive (`en_US.UTF-8` only; full archive 233 MB) | _proof_ | _proof_ | _proof_ |
| 4 | drop `xdg-utils` (drags perl 65 MB + ~40 perl modules; `xdg-open` is dead weight in a terminal+bar demo) | _proof_ | _proof_ | _proof_ |
| 5 | stop linking `man`/`doc`/`info` outputs into `/usr/share` | _proof_ | _proof_ | _proof_ |
| 6 | fuzzel's `resvg` (43 MB NAR via SVG icons) | -- | -- | kept: dropping SVG support guts the launcher for 43 MB; not worth it |
| 7 | ffmpeg chain via `wayvnc -> neatvnc -> ffmpeg-lib` (~90 MB: x264/x265/svt-av1/dav1d/v4l/… + libpulseaudio/mpg123/libopenmpt) | -- | -- | kept: only a custom wayvnc/neatvnc build removes it; last resort |

Headline after 1-5: _filled in during the live proof (target: at least halve
the pull size)_.

Method: root-env closure via `nix path-info --closure-size`; tarball bytes
via `ls -l` on the built store tarball; unpacked via `docker image inspect
.Size`; idle CPU/RAM via `docker stats` with a viewer attached after a 30 s
settle. `scoot` itself is 7 MB (stripped -- no debug-symbols problem);
`dejavu_fonts`/`tzdata`/`adwaita` are single-digit-to-tens MB, not the fight.
