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

| step | cut | unpacked (NAR) | pull | kept? |
|---|---|---|---|---|
| 0 | baseline `c17611a` | closure 2,117,410,632 B (1.972 GiB); image 2,160,960,931 B | 624,973,290 B (596.0 MiB) | -- |
| 1 | drop `mesa` (268.5 MB) + `libGL` + `libglvnd` + llvm swrast (533.8 MB); keep `libgbm` (0.1 MB: wayvnc links `libgbm.so.1`, verified via `ldd`; foot links no GL at all). All of `scoot`, `wayvnc`, `foot`, `fuzzel`, `scootbar`, `scootbg` start; session streams (live proof) | -802 MB | ~-240 MB | yes |
| 2 | replace python `websockify` + numpy/blas/lapack stack (~355 MB NAR) with `wsbridge` (5.3 MB static Go binary, stdlib only). Browser path re-proven live (HTTP 200, WS handshake, noVNC desktop, typing) | -350 MB | ~-110 MB | yes |
| 3 | single-locale glibc archive (222.6 MB -> 2.9 MB, `en_US.UTF-8` only) | -220 MB | ~-65 MB | yes |
| 4 | drop `xdg-utils` by dropping its only parent `wl-clipboard` (perl 56.7 MB + ~40 modules 4.2 MB + xdg/wl-clipboard ~4 MB). Clipboard/agent typing goes through the `scoot msg type` wtype shim | -65 MB | ~-20 MB | yes |
| 5 | stop linking `man`/`doc`/`info` into `/usr/share` (17 split outputs, 7.2 MB NAR) | ~0 (files still ride along inside package outputs in the layers; runnable-tree hygiene only) | ~0 | yes |
| extra | drop `openssl` CLI (keygen no longer needed: no TLS/RSA keys in the auth config) | -7.5 MB closure | -3.5 MB | yes |
| -- | nixpkgs pin 151fa4e -> 8ce4ef6 (aligns with scoot's input; restores Cachix hits) + version drift | residual ≈ -90 MB | residual | -- |
| 6 | fuzzel's `resvg` (41.0 MB NAR via SVG icons) | -- | -- | kept: dropping SVG support guts the launcher for 41 MB; not worth it |
| 7 | ffmpeg chain via `wayvnc -> neatvnc -> ffmpeg-lib` (ffmpeg-lib 28.3 MB NAR + codecs: x264/x265/svt-av1/dav1d/v4l/…; `libpulseaudio`+`mpg123`+`libopenmpt` ride along) | -- | -- | kept: only a custom wayvnc/neatvnc build removes it; last resort |
| final | this head | closure 581,575,592 B; image 593,991,680 B (`docker export`) | **185,474,953 B (176.9 MiB)** | **-70% pull, -73% unpacked** |

Headline after 1-5 (+openssl, +pin align): pull 596.0 MiB -> 176.9 MiB
(-70%), unpacked 2.013 GiB -> 566.4 MiB (-73%), root closure 1.972 GiB ->
554.6 MiB. Target (halve the pull) beaten by 2.3x.

Method: root-env closure via `nix path-info --closure-size`; tarball bytes
via `ls -l` on the built store tarball; unpacked via `docker image inspect
.Size`; idle CPU/RAM via `docker stats` with a viewer attached after a 30 s
settle. `scoot` itself is 7 MB (stripped -- no debug-symbols problem);
`dejavu_fonts`/`tzdata`/`adwaita` are single-digit-to-tens MB, not the fight.
