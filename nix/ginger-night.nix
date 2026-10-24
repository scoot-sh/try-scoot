# Ginger-night look data, read live from the scoot flake input.
#
# This is the single place the image reads the look from: the shipped look
# in `looks/ginger-night/look.toml` (appearance, bar colors, wallpaper
# mode/fill and the wallpaper store path, via `nix/lib/look-shipped.nix`;
# v0.3.0 retired the `nix/modules/desktop.nix` registry and
# `nix/modules/theme-look.nix`), the example TOMLs for bar/scoot shape, the
# foot palette file, the fuzzel CLI theme function, and the shared cursor.
# Bumping the `scoot` flake input moves all of these together; nothing here
# hand-copies a color except the nvim CursorLine fill (#1A1512, the foot
# palette's regular0, which the look does not name).
#
# Takes `lib` (nixpkgs lib) and the scoot flake (`scootFlake.outPath` is its
# source tree). Returns the look plus small derivations of it. The nvim
# colors below are only the L0/L1 fallback (no look): the look image seeds
# the profile's `nvim/colors/scoot-look.lua` + `nvim/plugin/scoot-look.lua`
# instead (see nix/desktop-profile.nix).
{lib}: {scootFlake}: let
  scootSrc = scootFlake.outPath;
  lookShipped = import "${scootSrc}/nix/lib/look-shipped.nix" {inherit lib;};
  ginger = lookShipped.looks.ginger-night;
  barExample = builtins.fromTOML (builtins.readFile "${scootSrc}/docs/examples/ginger-night/bar.toml");
  scootExample = builtins.fromTOML (builtins.readFile "${scootSrc}/docs/examples/ginger-night/scoot.toml");
  footExampleText = builtins.readFile "${scootSrc}/docs/examples/ginger-night/foot.ini";
  fuzzelThemeFn = import "${scootSrc}/nix/modules/fuzzel-theme.nix" {inherit lib;};
in {
  inherit ginger barExample scootExample footExampleText;
  cursor = lookShipped.cursor;
  fuzzelFlags = fuzzelThemeFn ginger;
  # The session wallpaper: the look's own file, byte-identical to
  # docs/assets/CatPeeking.png (the maintainer's asset, MIT). 926,588 B,
  # sha256 57d2e07f79f2c46a7e4165b209bbd24948f2ebfbfc653e0e584de6a1a1318f58.
  # Referenced, not vendored, so a scoot bump moves it; the
  # `look-no-third-party` check pins name+sha256 so any other image fails.
  wallpaperFile = ginger.wallpaper.image;
  # Foot palette, read from the look's file: the look tunes with FiraCode
  # Nerd Font, which this image ships (see nix/image.nix), so the font line
  # stays as the look wrote it. Only the shell is pinned: foot must launch
  # bash explicitly (interactive, with ~/.bashrc), never sh.
  footIni = lib.replaceStrings ["font=FiraCode Nerd Font:size=10.5"] ["font=FiraCode Nerd Font:size=10.5\nshell=/bin/bash"] footExampleText;
  # Starship prompt and btop setup, read live from the look's own files so a
  # scoot bump moves them with the palette (registry paths, not copies).
  starshipText = builtins.readFile ginger.appFiles.starship;
  btopConfText = builtins.readFile ginger.appFiles.btopConf;
  btopThemeText = builtins.readFile ginger.appFiles.btopTheme;
  # Neovim fallback for the L0/L1 diet steps (no look): generated from the
  # look's registry palette (bar colors) so the lean images still carry
  # ginger-night hues. The look image does NOT use this: it seeds the
  # profile's nvim leaf (colorscheme + plugin select) instead.
  nvimInit = ''
    " try-scoot nvim defaults (MIT): ginger-night palette, no plugins.
    set termguicolors
    set background=dark
    syntax on
    set number
    set cursorline
    set showmatch
    hi Normal guibg=${ginger.barColors.background} guifg=${ginger.barColors.foreground}
    hi Comment guifg=${ginger.barColors.dim}
    hi LineNr guifg=${ginger.barColors.dim}
    hi CursorLineNr guifg=${ginger.barColors.hover}
    hi CursorLine guibg=#1A1512
    hi StatusLine guibg=${ginger.barColors.accent} guifg=${ginger.barColors.background}
    hi StatusLineNC guibg=${ginger.barColors.dim} guifg=${ginger.barColors.background}
    hi Visual guibg=${ginger.barColors.hover} guifg=${ginger.barColors.background}
    hi Search guibg=${ginger.barColors.hover} guifg=${ginger.barColors.background}
    hi ErrorMsg guifg=${ginger.barColors.urgent}
  '';
}
