# Layers

- L0 `image-l0`: headless scoot + foot, wayvnc + noVNC. No bar, no wallpaper
  daemon, no launcher. The smallest thing that streams.
- L1 `image-l1`: L0 + `scootbar` + `scootbg` + `fuzzel` (the desktop profile
  packages from the scoot flake).
- final `image-try-scoot`: L1 + the default look (palette-color solid
  wallpaper generated at build time, themed foot/bar configs).

Measurements (aarch64, Asahi M2) are filled in during the build proof; see
docs/benchmark.md and the final report. Closure size via
`nix path-info --closure-size`; idle CPU/RAM via cgroup `cpu.stat` /
`memory.stat (anon)` with a viewer attached, 60 s after a 30 s settle.
