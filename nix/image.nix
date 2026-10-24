# Minimal OCI image for try-scoot: headless scoot + wayvnc + noVNC.
# Written fresh for this repo (MIT). Concepts follow standard NixOS
# dockerTools practice; no code is copied from the reference repo.
{
  lib,
  pkgs,
  dockerTools,
  buildEnv,
  runCommand,
  writeShellScriptBin,
  scootPkg,
  scootbgPkg,
  scootbarPkg,
  scootlaunchPkg,
  scootnotifyPkg,
  mocuPkg,
  scootFlake,
  homeManagerFlake,
}: {
  name,
  tag ? "latest",
  title ? "try-scoot",
  withBar ? true,
  withBg ? true,
  withLauncher ? true,
  withLook ? false,
  maxLayers ? 60,
}: let
  needBar = withBar;
  needBg = withBg;
  needLauncher = withLauncher;

  # Ginger-night look, read live from the scoot flake input (see
  # nix/ginger-night.nix): colors, wallpaper file, bar/scoot shapes, foot
  # palette and font, fuzzel flags, starship prompt, btop setup and cursor
  # all follow the scoot bump. The bar carries the look's own module set
  # where a container can back it (load/cpu/network; volume/battery need a
  # sound server or hardware that is not here) and the look's own icons via
  # the shipped Nerd fonts; the `look-no-third-party` check pins the
  # wallpaper name+sha256 so any other image fails.
  ginger = import ./ginger-night.nix {inherit lib;} {inherit scootFlake;};

  # Desktop config from the real `programs.scoot.desktop` profile
  # (see nix/desktop-profile.nix): evaluated here, seeded into
  # /defaults when the look is on. Lock/idle off (demo never locks).
  desktopProfile =
    import ./desktop-profile.nix {inherit lib pkgs scootFlake homeManagerFlake;}
    {withVirtualBinds = true;};

  # btop 1.4.7 defaults `show_disks` to True, which splits the mem box to
  # show a disks panel. A container exposes no block devices, so the panel
  # renders empty; the look's btop.conf sets no such key. Force it off
  # (replace if the look ever gains the key, else append).
  btopConfFixed = runCommand "btop.conf" {} ''
    cat ${pkgs.writeText "btop.conf.base" ginger.btopConfText} > $out
    if grep -q '^show_disks' $out; then
      sed -i 's/^show_disks.*/show_disks = False/' $out
    else
      echo 'show_disks = False' >> $out
    fi
  '';

  # Same fix for the profile's btop.conf (the desktop profile's file,
  # not the hand-read one above): a container has no block devices.
  btopConfProfileFixed = runCommand "btop-profile.conf" {} ''
    cat ${desktopProfile.btopConfig} > $out
    if grep -q '^show_disks' $out; then
      sed -i 's/^show_disks.*/show_disks = False/' $out
    else
      echo 'show_disks = False' >> $out
    fi
  '';

  # WS->TCP bridge + static file server (replaces python websockify + numpy).
  # Pure Go stdlib, static: the runtime closure is just this binary.
  # go test (unit + malformed-frame battery; fuzz seeds run as unit tests)
  # executes here so CI fails if the bridge regresses.
  wsbridge = runCommand "wsbridge" {nativeBuildInputs = [pkgs.go];} ''
    mkdir -p $out/bin $TMPDIR/gocache
    export GOCACHE=$TMPDIR/gocache GOFLAGS=-mod=mod
    export CGO_ENABLED=0
    cp -r ${./wsbridge} ./wsbridge-src
    chmod -R u+w ./wsbridge-src
    (cd ./wsbridge-src && go vet ./... && go test -count=1 ./...)
    (cd ./wsbridge-src && go build -trimpath -ldflags "-s -w" -o $out/bin/wsbridge .)
  '';

  # noVNC web tree, copied as real files (not symlinked): the nixpkgs `novnc`
  # package propagates python websockify into its closure (~360 MB with
  # numpy), and this image proxies with wsbridge instead. Copying at build
  # time keeps the files while the python stack stays out of the image.
  novncWeb = runCommand "novnc-web" {} ''
    mkdir -p $out
    cp -rL ${pkgs.novnc}/share/webapps/novnc/. $out/
  '';

  # Single-locale archive: only en_US.UTF-8 is ever used (LANG below).
  # Full glibcLocales is 233 MB unpacked; this is ~5 MB.
  tinyLocales = pkgs.glibcLocales.override {allLocales = false;};

  basePackages = with pkgs;
    [
      bashInteractive
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      which
      procps
      psmisc
      util-linux
      shadow
      curl
      gnutar
      gzip
      xz
      iproute2
      cacert
      tzdata
      tinyLocales
      glibc.bin
      s6
      execline
      dbus
      xkeyboard_config
      # no wl-clipboard: it propagates xdg-utils + perl (~100 MB unpacked)
      # for an unproven clipboard path. Agent typing goes through the
      # `scoot msg type` wtype shim instead.
      # GL: foot links no GL at all (ldd-clean); wayvnc needs only libgbm
      # (DT_NEEDED libgbm.so.1, verified via ldd), so the full mesa +
      # libGL + libglvnd stack (mesa 282 MB + llvm swrast 560 MB unpacked)
      # is replaced by libgbm alone. No /run/opengl-driver symlink: nothing
      # in the image consumes it (no GL env is set anywhere).
      libgbm
      fontconfig
      dejavu_fonts
      pkgs.nerd-fonts.droid-sans-mono
      pkgs.nerd-fonts.fira-code
      hicolor-icon-theme
      adwaita-icon-theme
      glib
      dconf
      shared-mime-info
      wayvnc
      wsbridge
      foot
      # Show-it-off apps: neovim (unwrapped: the wrapper's perl/python
      # providers cost ~190 MB NAR for nothing this image's plugin-free
      # config can use) and btop (the look ships a ginger-night theme for
      # it), plus starship (the look's prompt) and bash-completion.
      pkgs.neovim-unwrapped
      pkgs.btop
      pkgs.starship
      pkgs.bash-completion
    ]
    ++ lib.optionals needLauncher [fuzzel]
    ++ lib.optionals needBar [scootbarPkg]
    ++ lib.optionals needBg [scootbgPkg]
    # Mocu, scoot's default cursor theme since v0.2.1: the name the look's
    # cursor_theme/XCURSOR_THEME carry (via nix/lib/look-shipped.nix) has to resolve
    # to files in the image, and this is the package that provides them
    # (Mocu white, the configured theme; ~1.1 MB NAR, smaller than the
    # Vanilla-DMZ it replaces -- the package's `black` output with
    # Mocu-Black stays out). Follows the scoot bump like the rest.
    ++ lib.optionals withLook [mocuPkg]
    # Desktop profile packages (launcher script, notification daemon,
    # terminal): the generated binds carry absolute store paths, so the
    # targets must be in the closure. Only when the look is on; the
    # L0/L1 diet steps keep the hand-written configs below.
    ++ lib.optionals withLook desktopProfile.packages
    ++ [scootPkg];

  rootEnv = buildEnv {
    name = "${name}-root-env";
    paths = basePackages;
    pathsToLink = ["/bin" "/sbin" "/share" "/lib" "/libexec" "/etc"];
    # Collisions between distro data files (X11, fonts, icons) are benign
    # duplicates; the man/doc trees where most collisions live are stripped
    # from the image in `skeleton` below, so resolving each collision by hand
    # would only pin volatile file lists. Justification recorded; revisit if
    # checkCollisionContents ever reports differing bytes.
    ignoreCollisions = true;
  };

  fontsConf = pkgs.makeFontsConf {
    # DejaVu stays (fallback coverage, already in the closure); the Nerd
    # fonts are the look's own faces: DroidSansM Nerd Font Propo for the
    # bar's icons, FiraCode Nerd Font for foot (and the starship glyphs).
    fontDirectories = with pkgs; [dejavu_fonts pkgs.nerd-fonts.droid-sans-mono pkgs.nerd-fonts.fira-code];
  };

  # Wallpaper: the desktop profile's file when the look is on (the
  # look's own file from the scoot input, not vendored), else the old
  # solid plum for the L0/L1 diet steps (tiny generated PNG, no
  # third-party bytes).
  wallpaperPng =
    if withLook
    then desktopProfile.wallpaperFile
    else
      runCommand "try-scoot-wallpaper.png"
      {nativeBuildInputs = [pkgs.python3];} ''
        python3 - "$out" <<'PY'
        import struct, sys, zlib
        out = sys.argv[1]
        w, h = 1280, 800
        r, g, b = 0x1E, 0x1A, 0x2B
        raw = b"".join(b"\x00" + bytes([r, g, b]) * w for _ in range(h))
        def chunk(t, d):
            c = struct.pack(">I", len(d)) + t + d
            return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(raw, 9))
               + chunk(b"IEND", b""))
        open(out, "wb").write(png)
        PY
      '';

  scootConfig =
    if withLook
    then desktopProfile.scootConfig
    else
      pkgs.writeText "scoot-config.toml" ''
        [layout]
        default_column_width = 1

        [appearance]
        background_color = "#1e1a2b"
        prefer_no_csd = true

        [output]
        [virtual_input]
        enabled = true
        binds = true

        [wallpaper]
        ${lib.optionalString needBg ''            image = "/defaults/wallpaper.png"
                  mode = "fill"''}

        [autostart]
        ${lib.optionalString needBar ''          commands = [
                  "spawn scoot-bar-look",
                ]''}

        [binds]
        "alt+Return" = "spawn foot"
        "super+Return" = "spawn foot"
        "alt+t" = "spawn foot"
        "super+t" = "spawn foot"
        "alt+d" = "spawn fuzzel"
        "super+d" = "spawn fuzzel"
        "alt+q" = "close"
        "super+q" = "close"
        "alt+h" = "focus-column left"
        "alt+l" = "focus-column right"
        "super+h" = "focus-column left"
        "super+l" = "focus-column right"
      '';

  barConfig =
    if withLook
    # The bar from the desktop profile (scootbar module, themed by the
    # look): replaces the hand-written container subset. The bar daemon
    # still starts via the `scoot-bar-look` wrapper below (Nerd Font
    # for the icons), supervised by the session script.
    then desktopProfile.barConfig
    else
      pkgs.writeText "scoot-bar.toml" ''
        left = ["workspaces"]
        center = ["clock"]
        right = []

        [bar]
        height = 36

        [colors]
        background = "#1e1a2b"
        foreground = "#e6e1f5"
        accent = "#7c6cf0"

        [clock]
        format = "%H:%M"
      '';

  footConfig =
    if withLook
    # Foot from the desktop profile (theme module, look's palette +
    # FiraCode Nerd Font): replaces the hand-read foot.ini.
    then desktopProfile.footConfig
    else
      pkgs.writeText "foot.ini" ''
        font = DejaVu Sans Mono:size=11
        dpi-aware = no

        [colors-dark]
        background = 1e1a2b
        foreground = e6e1f5
      '';

  fuzzelConfig = pkgs.writeText "fuzzel.ini" ''
    [main]
    terminal = foot
    layer = overlay
  '';

  # The look tunes the bar with DroidSansM Nerd Font Propo (the glyphs the
  # module icons need); point the daemon at the shipped file.
  barLookWrapper = writeShellScriptBin "scoot-bar-look" ''
    exec ${scootbarPkg}/bin/scootbar daemon --font /usr/share/fonts/opentype/NerdFonts/DroidSansM/DroidSansMNerdFontPropo-Regular.otf "$@"
  '';

  # Bar helpers, written fresh for this repo (MIT): the bar streams, it does
  # not poll, so each script prints first and loops with a coarse sleep.
  # Load average every 10 s, CPU percent every 10 s from /proc/stat deltas.
  barLoad = writeShellScriptBin "scoot-bar-load" ''
    while :; do cut -d' ' -f1 /proc/loadavg; sleep 10; done
  '';
  barCpu = writeShellScriptBin "scoot-bar-cpu" ''
    # First sample: fail fast if /proc/stat is unreadable (the bar's exec
    # module restarts the helper, showing the `...` placeholder meanwhile).
    read -r _ a b c d e f g h guest guest_nice < /proc/stat || exit 1
    # Total counts the first eight fields only (user nice system idle
    # iowait irq softirq steal). guest/guest_nice are already included
    # in user/nice (fs/proc/stat.c: guest time is accounted to
    # CPUTIME_USER/CPUTIME_NICE as well as the separate GUEST counters),
    # so adding them would double-count.
    pt=$((a + b + c + d + e + f + g + h)); pi=$((d + e))
    while :; do
      sleep 10
      read -r _ a b c d e f g h guest guest_nice < /proc/stat || continue
      t=$((a + b + c + d + e + f + g + h)); i=$((d + e))
      dt=$((t - pt))
      if [ "$dt" -gt 0 ]; then printf '%s%%\n' "$((100 * (dt - (i - pi)) / dt))"; fi
      pt=$t; pi=$i
    done
  '';

  # Themed launcher: fuzzel with the look's colors as CLI flags (the same
  # mechanism upstream's fuzzel-theme.nix ships for the desktop pickers).
  # Binds spawn this when the look is on; plain `fuzzel` stays available.
  fuzzelLookWrapper = writeShellScriptBin "fuzzel-look" ''
    exec ${pkgs.fuzzel}/bin/fuzzel${ginger.fuzzelFlags} "$@"
  '';

  wtypeShim = writeShellScriptBin "wtype" ''
    literal=0
    if [ "''${1:-}" = "--" ]; then literal=1; shift; fi
    if [ "$literal" = 0 ]; then
      for arg in "$@"; do
        case "$arg" in
          -*) echo "wtype: unsupported option $arg (scoot shim)" >&2; exit 64 ;;
        esac
      done
    fi
    [ "$#" -gt 0 ] || exit 0
    exec ${scootPkg}/bin/scoot msg type "$*"
  '';

  etcFiles = runCommand "${name}-etc" {} ''
    mkdir -p $out/etc/{pam.d,fonts,ssl/certs}
    cat > $out/etc/passwd <<'PW'
    root:x:0:0:root:/root:/bin/bash
    abc:x:911:911::/config:/bin/bash
    nobody:x:65534:65534:nobody:/nonexistent:/bin/false
    PW
    cat > $out/etc/group <<'GR'
    root:x:0:
    audio:x:29:abc
    video:x:44:abc
    abc:x:911:
    nobody:x:65534:
    nogroup:x:65533:
    GR
    cat > $out/etc/shadow <<'SH'
    root:!:19000:0:99999:7:::
    abc:!:19000:0:99999:7:::
    nobody:!:19000:0:99999:7:::
    SH
    cp $out/etc/group $out/etc/gshadow
    sed -i 's/:x:/:!::/' $out/etc/gshadow
    cat > $out/etc/sudoers <<'SD'
    root ALL=(ALL:ALL) ALL
    SD
    for f in sudo other login su; do
      cat > $out/etc/pam.d/$f <<'PAM'
    auth     sufficient pam_permit.so
    account  required   pam_permit.so
    password required   pam_deny.so
    session  required   pam_permit.so
    PAM
    done
    cat > $out/etc/nsswitch.conf <<'NS'
    passwd: files
    group: files
    shadow: files
    hosts: files dns
    NS
    cat > $out/etc/os-release <<'OS'
    NAME="try-scoot"
    ID=nixos
    PRETTY_NAME="try-scoot minimal scoot desktop"
    OS
    cat > $out/etc/profile <<'PR'
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    PR
    echo "try-scoot" > $out/etc/hostname
    cp ${fontsConf} $out/etc/fonts/fonts.conf
    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-bundle.crt
  '';

  skeleton = runCommand "${name}-skeleton" {} ''
    mkdir -p $out/usr $out/lib $out/lib64 $out/defaults $out/etc/s6 $out/usr/local/bin
    ln -s ${rootEnv}/bin     $out/usr/bin
    ln -s ${rootEnv}/sbin    $out/usr/sbin
    # /usr/share minus the doc trees: buildEnv pulls *-man outputs of every
    # package into share/man (tens of MB of man/doc/info for tools nobody
    # reads inside a kiosk image). Symlink-farm everything else so fonts,
    # XKB keymaps, glib schemas, mime and icons keep working.
    mkdir -p $out/usr/share
    for d in ${rootEnv}/share/*; do
      case "$(basename "$d")" in
        man|doc|info|gtk-doc) ;;
        *) ln -s "$d" $out/usr/share/ ;;
      esac
    done
    ln -s ${rootEnv}/lib     $out/usr/lib
    ln -s ${rootEnv}/libexec $out/usr/libexec
    ln -s ${rootEnv}/etc     $out/usr/etc
    ln -s usr/bin            $out/bin
    ln -s usr/sbin           $out/sbin
    for l in ${pkgs.glibc}/lib/ld-linux*; do
      ln -s "$l" $out/lib/; ln -s "$l" $out/lib64/
    done
    mkdir -p $out/run
    # noVNC web client as real files (see novncWeb above: keeps the python
    # stack out of the image closure). novnc/run serves this path.
    mkdir -p $out/usr/share/webapps
    cp -rL ${novncWeb}/. $out/usr/share/webapps/novnc/
    cp -r ${../rootfs/defaults}/. $out/defaults/
    cp ${wallpaperPng} $out/defaults/wallpaper.png
    cp ${scootConfig} $out/defaults/scoot-config.toml
    cp ${barConfig} $out/defaults/bar.toml
    cp ${footConfig} $out/defaults/foot.ini
    cp ${fuzzelConfig} $out/defaults/fuzzel.ini
    ${
      if withLook
      then ''
        cp ${desktopProfile.starshipConfig} $out/defaults/starship.toml
        cp ${desktopProfile.notifyConfig} $out/defaults/notify.toml
        ${lib.optionalString (desktopProfile.launchConfig != null) "cp ${desktopProfile.launchConfig} $out/defaults/launch.toml"}
      ''
      else ''
        cp ${pkgs.writeText "starship.toml" ginger.starshipText} $out/defaults/starship.toml
      ''
    }
    ${
      if withLook
      then ''
        # nvim from the desktop profile (scoot v0.6.1+): the look's
        # colorscheme + plugin select replace the hand-written colors.
        # Minimal init (options only, no colors): the colorscheme arrives
        # via the profile's colors/plugin files seeded below.
        cp ${desktopProfile.nvimColors} $out/defaults/nvim-colors.lua
        cp ${desktopProfile.nvimPlugin} $out/defaults/nvim-plugin.lua
        cat > $out/defaults/nvim-init.vim <<'VIM'
        " try-scoot nvim defaults (MIT): options only, no colors.
        " Colors follow the ginger-night look via nvim/colors/scoot-look.lua
        " + nvim/plugin/scoot-look.lua from the desktop profile.
        set termguicolors
        set background=dark
        syntax on
        set number
        set cursorline
        set showmatch
        VIM
        cp ${desktopProfile.mimeApps} $out/defaults/mimeapps.list
        cp ${desktopProfile.editorDesktopEntry} $out/defaults/scoot-editor.desktop
      ''
      else ''
        cp ${pkgs.writeText "init.vim" ginger.nvimInit} $out/defaults/nvim-init.vim
      ''
    }
    ${
      if withLook
      then ''
        cp ${btopConfProfileFixed} $out/defaults/btop.conf
        cp ${desktopProfile.btopTheme} $out/defaults/btop-theme.theme
      ''
      else ''
        cp ${btopConfFixed} $out/defaults/btop.conf
        cp ${pkgs.writeText "ginger-night.theme" ginger.btopThemeText} $out/defaults/btop-theme.theme
      ''
    }
    mkdir -p $out/usr/local/bin
    cp ${barLookWrapper}/bin/scoot-bar-look $out/usr/local/bin/scoot-bar-look
    cp ${barLoad}/bin/scoot-bar-load $out/usr/local/bin/scoot-bar-load
    cp ${barCpu}/bin/scoot-bar-cpu $out/usr/local/bin/scoot-bar-cpu
    cp ${wtypeShim}/bin/wtype $out/usr/local/bin/wtype
    chmod +x $out/usr/local/bin/scoot-bar-look $out/usr/local/bin/scoot-bar-load $out/usr/local/bin/scoot-bar-cpu $out/usr/local/bin/wtype
    # Nerd Fonts ride under OFL-1.1: carry the license text in the image
    # (the nixpkgs font packages ship no license file).
    mkdir -p $out/usr/share/doc/nerd-fonts
    cp ${../rootfs/defaults/OFL.txt} $out/usr/share/doc/nerd-fonts/OFL.txt
    ${lib.optionalString withLook ''
      cp ${fuzzelLookWrapper}/bin/fuzzel-look $out/usr/local/bin/fuzzel-look
      chmod +x $out/usr/local/bin/fuzzel-look
    ''}
    cp -r ${../rootfs/s6}/. $out/etc/s6/
    cp ${../rootfs/init} $out/init
    chmod +x $out/init $out/defaults/*.sh
    find $out/etc/s6 -name run -exec chmod +x {} +
  '';

  imageEnv =
    [
      "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      "HOME=/config"
      "TITLE=${title}"
      "LANG=en_US.UTF-8"
      "LOCALE_ARCHIVE=${tinyLocales}/lib/locale/locale-archive"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "XDG_DATA_DIRS=/usr/share"
      "FONTCONFIG_FILE=/etc/fonts/fonts.conf"
      "XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/share/X11/xkb"
      "XDG_CURRENT_DESKTOP=scoot"
      "XDG_SESSION_TYPE=wayland"
      "GDK_BACKEND=wayland"
      "TERMINAL=foot"
      "EDITOR=nvim"
      "VISUAL=nvim"
    ]
    ++ lib.optionals withLook [
      "XCURSOR_THEME=${ginger.cursor.name}"
      "XCURSOR_SIZE=${toString ginger.cursor.size}"
    ];
in
  dockerTools.buildLayeredImage {
    inherit name tag maxLayers;
    # Pinned (not "now") so identical trees build bit-identical tarballs.
    created = "2026-01-01T00:00:00Z";
    contents = [skeleton etcFiles];
    extraCommands = ''
      mkdir -p tmp config run var/tmp
      chmod 1777 tmp var/tmp
    '';
    fakeRootCommands = ''
      for f in etc/passwd etc/group etc/shadow etc/gshadow; do
        target="$(readlink -f "$f")"
        rm -f "$f"
        cp "$target" "$f"
        chown 0:0 "$f"
      done
      chmod 0644 etc/passwd etc/group
      chmod 0640 etc/shadow etc/gshadow
      chown 911:911 config
    '';
    config = {
      Cmd = ["/init"];
      Env = imageEnv;
      ExposedPorts = {
        "6080/tcp" = {};
        "5900/tcp" = {};
      };
      Volumes = {"/config" = {};};
      WorkingDir = "/config";
      Labels = {
        "org.opencontainers.image.title" = title;
        "org.opencontainers.image.description" = "Minimal scoot desktop in the browser (headless scoot + wayvnc + noVNC)";
        "org.opencontainers.image.source" = "https://github.com/scoot-sh/try-scoot";
      };
    };
  }
