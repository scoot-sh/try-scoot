# Ginger-night look data, read live from the scoot flake input.
#
# This is the single place the image reads the look from: the registry in
# `nix/modules/desktop.nix` (appearance, bar colors, wallpaper mode/fill and
# the wallpaper store path), the example TOMLs for bar/scoot shape, the
# foot palette file, the fuzzel CLI theme function, and the shared cursor.
# Bumping the `scoot` flake input moves all of these together; nothing here
# hand-copies a color except the DejaVu font swap (documented below).
#
# Takes `lib` (nixpkgs lib) and the scoot flake (`scootFlake.outPath` is its
# source tree). Returns the look plus small derivations of it.
{lib}: {scootFlake}: let
  scootSrc = scootFlake.outPath;
  desktop = import "${scootSrc}/nix/modules/desktop.nix" {inherit lib;};
  ginger = desktop.looks.ginger-night;
  barExample = builtins.fromTOML (builtins.readFile "${scootSrc}/docs/examples/ginger-night/bar.toml");
  scootExample = builtins.fromTOML (builtins.readFile "${scootSrc}/docs/examples/ginger-night/scoot.toml");
  footExampleText = builtins.readFile "${scootSrc}/docs/examples/ginger-night/foot.ini";
  fuzzelThemeFn = import "${scootSrc}/nix/modules/fuzzel-theme.nix" {inherit lib;};
  themeLook = import "${scootSrc}/nix/modules/theme-look.nix" {inherit lib;};
in {
  inherit ginger barExample scootExample footExampleText;
  cursor = themeLook.cursor;
  fuzzelFlags = fuzzelThemeFn ginger;
  # The session wallpaper: the look's own file, byte-identical to
  # docs/assets/CatPeeking.png (the maintainer's asset, MIT). 926,588 B,
  # sha256 57d2e07f79f2c46a7e4165b209bbd24948f2ebfbfc653e0e584de6a1a1318f58.
  # Referenced, not vendored, so a scoot bump moves it; the
  # `look-no-third-party` check pins name+sha256 so any other image fails.
  wallpaperFile = ginger.wallpaper.image;
  # Foot palette, read from the look's file with only the font swapped:
  # the look tunes with FiraCode Nerd Font (not shipped: DejaVu is already
  # in the closure, zero added bytes; Nerd glyphs are unused by the
  # container bar's minimal modules). Pad, cursor style, palette and
  # selection colors follow the look on bump.
  footIni = lib.replaceStrings ["font=FiraCode Nerd Font:size=10.5"] ["font=DejaVu Sans Mono:size=11\ndpi-aware=no"] footExampleText;
}
