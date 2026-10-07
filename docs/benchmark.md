# Benchmark

Filled in during the live proof on the Asahi M2 (aarch64):

- pull size: `docker images ghcr.io/scoot-sh/try-scoot` (compressed + unpacked).
- time-to-first-frame: seconds from `docker run` to the first decodable
  frame in a headless browser (noVNC canvas pixels change / RFB update
  received), measured with `date +%s.%N` around container start and the
  first-frame probe.
- reference deltas: closure size and idle CPU/RAM vs
  `image-scoot-dev` / `image-scoot-vnc` in `yackey-labs/nixos-webtop`.
