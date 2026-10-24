# Desktop config from the real `programs.scoot.desktop` profile.
#
# Evaluates a home-manager configuration at build time (home-manager
# follows nixpkgs; scoot's `homeModules` from the scoot flake input)
# with the ginger-night look and container-appropriate slots, then
# exposes the generated files for the image's /defaults seeding.
#
# Slots that need systemd/hardware are off: idle/lock/mediaInhibit
# (a demo must never lock or blank; no swayidle/swaylock in the
# image), audio, network/Bluetooth pickers, power, clipboard (would
# pull wl-clipboard + perl), capture, displays, nightlight,
# automount, auth/secrets. Input method stays opt-in (off).
#
# Kept on: launcher (scootlaunch, no daemon), notifications
# (scootnotify config; the daemon starts via s6 only if it runs
# headless without systemd), theme (foot/starship/btop files),
# terminal, bar (via scootbar module), wallpaper, keys.
#
# Container-specific overrides (not in the profile): virtual_input
# for remote binds, and the first-run autostart columns (foot, btop).
# Takes `withVirtualBinds`: true for the VNC image (remote chords
# through virtual-keyboard), false for Selkies (seat keymap; the flag
# is a no-op there).
{
  lib,
  pkgs,
  scootFlake,
  homeManagerFlake,
}: {withVirtualBinds ? true}: let
  hmLib = homeManagerFlake.lib.homeManagerConfiguration;
  # Look values for static theming (appearance, wallpaper): the
  # profile's runtime look layer needs `scoot look sync` + catalog,
  # which the container does not run. Bake the look's own values
  # into the generated config instead, read live from the scoot
  # flake so the bump moves them. Binds/autostart/virtual_input
  # still come from the profile below.
  ginger = import ./ginger-night.nix {inherit lib;} {inherit scootFlake;};
  hmConfig = hmLib {
    inherit pkgs;
    modules = [
      scootFlake.homeModules.scoot
      scootFlake.homeModules.scootbar
      {
        home.username = "abc";
        home.homeDirectory = "/config";
        home.stateVersion = "26.05";
        programs.home-manager.enable = false;
        # No XDG user dirs in the container (avoids perl/xdg-utils
        # closure growth; the image seeds only what scoot reads).
        xdg.userDirs.enable = false;

        programs.scoot.enable = true;
        programs.scoot.desktop.enable = true;
        programs.scoot.look = "ginger-night";
        # Only the demo look in the image (default is every shipped
        # look; the others would ride the closure for nothing).
        programs.scoot.looks = ["ginger-night"];

        # Bar modules for the container: what a container can back
        # (workspaces, clock, window title, load/cpu/network).
        # Volume/battery need hardware; launcher buttons need apps.
        # Static theming from the look's own files (no runtime layer
        # in the container): colors, shape and icons baked here,
        # following the scoot bump via nix/ginger-night.nix.
        programs.scootbar.enable = true;
        programs.scootbar.systemd.enable = false;
        programs.scootbar.settings = {
          left = ["workspaces"];
          center = ["clock"];
          right = ["window-title" "load" "cpu" "network"];
          bar = {
            height = ginger.barExample.bar.height;
            margin = ginger.barExample.bar.margin;
            radius = ginger.barExample.bar.radius;
            opacity = ginger.barExample.bar.opacity;
            font-size = ginger.barExample.bar.font-size;
            padding = ginger.barExample.bar.padding;
            spacing = ginger.barExample.bar.spacing;
            separator = ginger.barExample.bar.separator;
          };
          colors = {
            background = ginger.ginger.barColors.background;
            foreground = ginger.ginger.barColors.foreground;
            accent = ginger.ginger.barColors.accent;
            hover = ginger.ginger.barColors.hover;
            dim = ginger.ginger.barColors.dim;
            urgent = ginger.ginger.barColors.urgent;
          };
          workspaces = {
            pill-shape = ginger.barExample.workspaces.pill-shape;
            pill-inset = ginger.barExample.workspaces.pill-inset;
            item-gap = ginger.barExample.workspaces.item-gap;
            margin = ginger.barExample.workspaces.margin;
            disc = ginger.barExample.workspaces.disc;
            inactive-color = ginger.barExample.workspaces.inactive-color;
          };
          window-title = {
            icon = ginger.barExample."window-title".icon;
            show-app-id = ginger.barExample."window-title".show-app-id;
            max-width = ginger.barExample."window-title".max-width;
          };
          clock = {
            format = ginger.barExample.clock.format;
            icon = ginger.barExample.clock.icon;
          };
          exec.load = {
            command = ["/usr/local/bin/scoot-bar-load"];
            icon = ginger.barExample.exec.load.icon;
            placeholder = "...";
          };
          exec.cpu = {
            command = ["/usr/local/bin/scoot-bar-cpu"];
            icon = ginger.barExample.exec.cpu.icon;
            placeholder = "...";
          };
          network = {
            icon-wifi = ginger.barExample.network.icon-wifi;
            icon-ethernet = ginger.barExample.network.icon-ethernet;
            show-text = ginger.barExample.network.show-text;
          };
        };

        # No lock or blanking in the demo.
        programs.scoot.desktop.idle.enable = false;
        programs.scoot.desktop.idle.lock.enable = false;
        programs.scoot.desktop.idle.mediaInhibit.enable = false;

        # No hardware/systemd services in the container.
        programs.scoot.desktop.audio.enable = false;
        programs.scoot.desktop.apps.network.enable = false;
        programs.scoot.desktop.apps.bluetooth.enable = false;
        programs.scoot.desktop.power.enable = false;
        programs.scoot.desktop.clipboard.enable = false;
        programs.scoot.desktop.capture.enable = false;
        programs.scoot.desktop.displays.enable = false;
        programs.scoot.desktop.nightlight.enable = false;
        programs.scoot.desktop.automount.enable = false;
        programs.scoot.desktop.auth.enable = false;
        programs.scoot.desktop.secrets.enable = false;
        programs.scoot.desktop.inputMethod.enable = false;
        # Terminal stays (foot); no file manager in the image.
        programs.scoot.desktop.apps.fileManager.enable = false;

        # No GTK/Qt theming in the container (no GTK/Qt apps ship
        # here; foot/btop are terminal, nvim is terminal too but its
        # colorscheme follows the look). Keeps qt6ct/adwaita-qt
        # out of the closure; foot/starship/btop/nvim theming stays on
        # via the theme module's terminal/shell/monitor/editor leaves.
        programs.scoot.desktop.theme.targets.gtk.enable = false;
        programs.scoot.desktop.theme.targets.qt.enable = false;

        # nvim is the image's default editor (EDITOR/VISUAL, text/plain
        # via the profile, colorscheme following ginger-night): link the
        # look's colorscheme and select it (no programs.neovim in the
        # container, so the selection lands).
        programs.scoot.desktop.theme.targets.editor.nvim.enable = true;
        programs.scoot.desktop.apps.editor.default = "nvim";
        # Keep the image lean: the profile default is wrapped neovim
        # (perl/python providers, ~190 MB NAR for nothing a plugin-free
        # config can use); the image already ships neovim-unwrapped.
        programs.scoot.desktop.apps.editor.package = pkgs.neovim-unwrapped;

        # Launcher via fuzzel (not the profile's default scootlaunch):
        # fuzzel carries the look's colors as CLI flags (static,
        # no runtime look layer needed), while scootlaunch themes
        # through the runtime layer the container does not run.
        # One-line override, same binds.
        programs.scoot.desktop.launcher.daemon = "fuzzel";

        # Container overrides: remote binds + first-run columns.
        programs.scoot.settings.virtual_input.enabled = true;
        programs.scoot.settings.virtual_input.binds = withVirtualBinds;
        programs.scoot.settings.autostart.commands = [
          "spawn scoot-bar-look"
          "spawn foot"
          "spawn foot btop"
        ];

        # Static look (no runtime `scoot look sync` in the container):
        # appearance, wallpaper and layout baked from the look's own
        # files (via nix/ginger-night.nix, following the scoot bump).
        # Binds/autostart above still come from the profile.
        programs.scoot.settings.layout = {
          default_column_width = 1;
          gap = ginger.scootExample.layout.gap;
        };
        programs.scoot.settings.appearance = {
          background_color = ginger.ginger.appearance.background_color;
          corner_radius = ginger.scootExample.appearance.corner_radius;
          focus_ring_width = ginger.scootExample.appearance.focus_ring_width;
          focus_ring_inactive_width = ginger.scootExample.appearance.focus_ring_inactive_width;
          focus_ring_active_color = ginger.ginger.appearance.focus_ring_active_color;
          focus_ring_inactive_color = ginger.ginger.appearance.focus_ring_inactive_color;
          cursor_theme = ginger.cursor.name;
          cursor_size = ginger.cursor.size;
          prefer_no_csd = true;
        };
        programs.scoot.settings.wallpaper = {
          image = "/defaults/wallpaper.png";
          mode = ginger.ginger.wallpaper.mode;
          fill = ginger.ginger.wallpaper.fill;
        };
        programs.scoot.settings.binds = {
          "alt+Return" = "spawn foot";
          "super+Return" = "spawn foot";
          "alt+t" = "spawn foot";
          "super+t" = "spawn foot";
          "alt+q" = "close";
          "super+q" = "close";
          "alt+h" = "focus-column left";
          "alt+l" = "focus-column right";
          "super+h" = "focus-column left";
          "super+l" = "focus-column right";
        };

        # No hardware keys in the container: drop the tools (keeps the
        # closure lean: no wireplumber/playerctl/brightnessctl) and the
        # binds (a demo must never lock; no locker in the image).
        programs.scoot.desktop.keys.brightnessPackage = null;
        programs.scoot.desktop.keys.volumePackage = null;
        programs.scoot.desktop.keys.mediaPackage = null;
        programs.scoot.desktop.keys.binds.brightnessUp.enable = false;
        programs.scoot.desktop.keys.binds.brightnessDown.enable = false;
        programs.scoot.desktop.keys.binds.volumeUp.enable = false;
        programs.scoot.desktop.keys.binds.volumeDown.enable = false;
        programs.scoot.desktop.keys.binds.volumeMute.enable = false;
        programs.scoot.desktop.keys.binds.micMute.enable = false;
        programs.scoot.desktop.keys.binds.mediaPlay.enable = false;
        programs.scoot.desktop.keys.binds.mediaPause.enable = false;
        programs.scoot.desktop.keys.binds.mediaStop.enable = false;
        programs.scoot.desktop.keys.binds.mediaNext.enable = false;
        programs.scoot.desktop.keys.binds.mediaPrev.enable = false;
        programs.scoot.desktop.keys.binds.lock.enable = false;
      }
    ];
  };
  cfg = hmConfig.config;
  # Helper: resolve an xdg.configFile entry to a store path, whether
  # it was set via `source` or `text`.
  fileOf = name: fallback: let
    entry = cfg.xdg.configFile.${name} or null;
  in
    if entry == null
    then fallback
    else if entry.source or null != null
    then entry.source
    else if entry.text or null != null
    then pkgs.writeText name entry.text
    else fallback;
  # Helper for xdg.dataFile entries (the editor desktop entry).
  dataFileOf = name: fallback: let
    entry = cfg.xdg.dataFile.${name} or null;
  in
    if entry == null
    then fallback
    else if entry.source or null != null
    then entry.source
    else if entry.text or null != null
    then pkgs.writeText (baseNameOf name) entry.text
    else fallback;
  # btop theme lives under btop/themes/<name>; find it.
  btopThemeName = let
    names = builtins.filter (n: lib.hasPrefix "btop/themes/" n) (builtins.attrNames cfg.xdg.configFile);
  in
    if names == []
    then null
    else builtins.head names;
  # Look catalog for the runtime layer (`scoot look sync`): the
  # declared default plus the linked looks/rendered trees. The
  # container seeds these into /config and runs `scoot look sync`
  # at startup (no home-manager activation in the image).
  lookDefault = fileOf "scoot/look-default" null;
  lookData = cfg.xdg.dataFile or {};
in {
  inherit hmConfig;
  inherit lookDefault lookData;
  # Packages the profile installs (launcher script, notification
  # daemon, terminal, etc.): included in the image closure so the
  # absolute store paths in the generated binds resolve. Filtered to
  # keep the image lean: drop home-manager infrastructure (man-db,
  # manpage, session vars, mime/fontconfig dummies) and theming for
  # toolkits with no apps in the image (qt6ct, adwaita-qt: no GTK/Qt
  # apps ship here). xdg-utils (perl) stays out the same way
  # wl-clipboard does: nothing in the container reads it.
  packages = builtins.filter (p: let
    n = p.pname or p.name or "";
  in
    !(lib.elem n [
      "man-db"
      "home-configuration-reference-manpage"
      "hm-session-vars.sh"
      "dummy-xdg-mime-dirs1"
      "dummy-xdg-mime-dirs2"
      "dummy-fc-dir1"
      "dummy-fc-dir2"
      "xdg-utils"
      "xdg-user-dirs"
      "qt6ct"
      "adwaita-qt"
    ]))
  cfg.home.packages;
  # The generated files the image seeds into /defaults.
  scootConfig = fileOf "scoot/config.toml" null;
  barConfig = fileOf "scoot/bar.toml" null;
  footConfig = fileOf "foot/foot.ini" null;
  starshipConfig = fileOf "starship.toml" null;
  btopConfig = fileOf "btop/btop.conf" null;
  btopTheme =
    if btopThemeName == null
    then null
    else fileOf btopThemeName null;
  btopThemeNameBase =
    if btopThemeName == null
    then null
    else baseNameOf btopThemeName;
  launchConfig = fileOf "scoot/launch.toml" null;
  notifyConfig = fileOf "scoot/notify.toml" null;
  # nvim look leaf from the profile (v0.6.1+): the colorscheme link
  # (always with the editor target on) and the plugin select (with
  # targets.editor.nvim.enable). Replaces the hand-written init colors.
  nvimColors = fileOf "nvim/colors/scoot-look.lua" null;
  nvimPlugin = fileOf "nvim/plugin/scoot-look.lua" null;
  # text/plain association via the profile (editor.default): mimeapps
  # list + terminal desktop entry running foot -e <editor>.
  mimeApps = fileOf "mimeapps.list" null;
  editorDesktopEntry = dataFileOf "applications/scoot-editor.desktop" null;
  # Wallpaper file from the look (store path, not generated).
  wallpaperFile = scootFlake.outPath + "/docs/examples/ginger-night/wallpaper.png";
  # For assertions: no idle/lock packages in the closure.
  hasSwayidle = builtins.elem "swayidle" (map (p: p.pname or p.name or "") cfg.home.packages);
}
