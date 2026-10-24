# Layers

- L0 `image-l0`: headless scoot + foot, wayvnc + noVNC. No bar, no wallpaper
  daemon, no launcher. The smallest thing that streams.
- L1 `image-l1`: L0 + `scootbar` + `scootbg` + `fuzzel` (the desktop profile
  packages from the scoot flake).
- final `image-try-scoot`: L1 + the ginger-night look (the look's wallpaper
  from the scoot flake input, `fit` on its black fill; foot palette and
  FiraCode Nerd Font, bar colors/shape with the look's load/cpu/network
  modules and Nerd icons, scoot appearance/rings, fuzzel theme, starship
  prompt, btop setup and cursor read from the flake -- see
  `nix/ginger-night.nix`; volume/battery/buttons stay out: they need a
  sound server, hardware, or apps not shipped here).

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

## Show-it-off delta (this round)

Marginal NAR 127,347,152 B across 22 new store paths (closure of the added
top-level packages minus what the image already carried):

| added | NAR | pull delta share | why |
|---|---|---|---|
| FiraCode Nerd Font | 48,987,800 B | ~1/3 of the pull delta | the look's terminal face; one output, all weights; starship glyphs need it |
| neovim-unwrapped | 34,067,320 B + ~17 MB tree-sitter/luajit/libuv | ~1/4 | the editor; unwrapped skips ~190 MB of perl/python providers |
| starship | 14,678,024 B | small | the look's prompt |
| DroidSansM Nerd Font Propo | 7,359,008 B | small | the bar's icons |
| btop | 2,123,488 B | tiny | the look ships a theme for it |
| bash-completion | 1,271,696 B | tiny | shell completion |

Measured image delta: pull 187,027,379 B -> 243,967,344 B (+56,939,964 B,
+30.4%), unpacked 599,079,936 B -> 728,530,944 B (+129,451,008 B), matching
the marginal NAR plus config bytes. Still 61% below the pre-diet pull.

## scoot v0.2.1 bump (this round)

Root-env closure NAR +149,535,112 B, pull +50,227,084 B (+20.6%); full
numbers in docs/benchmark.md. Almost all of it is scoot's own single-build
closure (the Xwayland server runtime now on scoot's `PATH`, plus the
compiled-in xwayland/gpu-scanout code): diet step 1's mesa cut still holds
for the image's own `basePackages` (wayvnc still needs only `libgbm.so.1`,
foot still links no GL), and the Xwayland runtime is kept deliberately --
it is scoot's published shape since 0.2.1, not a dependency the image can
drop without forking scoot. Partly offset by the cursor swap
(vanilla-dmz -> Mocu, -2,399,376 B NAR). L0 279,484,262 B, L1 293,156,814 B:
the diet steps still build the solid-plum path in the same shape.

## scoot v0.6.0 bump + desktop profile (this round)

Pull 295,111,126 B -> 295,929,188 B (+818,062 B, +0.3%), unpacked
884,028,928 B -> 883,683,840 B (-345,088 B, -0.0%); full numbers in
docs/benchmark.md. The image now evaluates the real
`programs.scoot.desktop` profile at build time (home-manager follows
nixpkgs; scoot flake `homeModules`, ginger-night look, lock/idle off;
see `nix/desktop-profile.nix`): binds/autostart/virtual_input, bar,
foot, launcher, wallpaper and cursor follow the profile, with
container overrides (no systemd/hardware services, static look values
since the container runs s6). Launcher via fuzzel (static theme
flags), notifications via scootnotify (daemon supervised in
`session.sh`). No swayidle/swaylock in the closure; `scoot msg locked`
is false. Diet step 1 still holds (layer carries `mesa-libgbm` only).
Perl/qt6ct/adwaita-qt/man-db filtered out of the profile closure to
keep the image lean.

Why FiraCode Nerd Font ships whole instead of a subset: a Nerd-Font subset would break the look's icon coverage on the next scoot bump (any new glyph the look adopts would need re-subsetting, and foot, starship and the bar each draw from different corners of the font), so the image carries the font package as nixpkgs ships it -- one output, all weights -- and follows the look on bump rather than pinning a glyph list that silently rots.

Method: root-env closure via `nix path-info --closure-size`; tarball bytes
via `ls -l` on the built store tarball; unpacked via `docker export` (the
`docker image inspect .Size` field double-counts shared layers on some
engines -- 2.25 GB reported for a 594 MB export -- so it is not used);
idle CPU/RAM via `docker stats` with a viewer attached after a 30 s
settle. `scoot` itself is 7 MB (stripped -- no debug-symbols problem);
`dejavu_fonts`/`tzdata`/`adwaita` are single-digit-to-tens MB, not the fight.

## Selkies variant layers (`:selkies` tag)

Built by `nix/image-selkies.nix` (the default builder above is untouched);
numbers are tarball bytes and `docker export`, same method:

- `image-selkies-l0`: Selkies 2.0.0 + PulseAudio + GL stack, no desktop.
  The compositor comes up empty; the web UI loads and the x264 software
  encoder runs. Pull 494,739,938 B (471.8 MiB), unpacked 1,691,484,160 B
  (1.575 GiB), idle 0.18% / 71.7 MiB.
- `image-try-scoot-selkies`: L0 + nested scoot + `scootbar` + `scootbg` +
  `fuzzel` + the default look. The desktop itself adds ~20 MB of pull
  (514,428,977 B / 490.6 MiB; unpacked 1,753,701,888 B / 1.633 GiB); the
  rest of the gap to the VNC tag is the Selkies stack the VNC diet
  deleted: mesa/GL back in, the Python runtime with the Selkies app and
  the pixelflux/pcmflux wheels, and the PulseAudio daemon. Idle 0.26% /
  119.2 MiB without a viewer, 0.19% / 123.9 MiB with a viewer on a static
  screen.
