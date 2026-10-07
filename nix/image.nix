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

  # WS->TCP bridge + static file server (replaces python websockify + numpy).
  # Pure Go stdlib, static: the runtime closure is just this binary.
  wsbridge = runCommand "wsbridge" {nativeBuildInputs = [pkgs.go];} ''
    mkdir -p $out/bin $TMPDIR/gocache
    export GOCACHE=$TMPDIR/gocache GOFLAGS=-mod=mod
    export CGO_ENABLED=0
    go build -trimpath -ldflags "-s -w" -o $out/bin/wsbridge ${./wsbridge/main.go}
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
      hicolor-icon-theme
      adwaita-icon-theme
      glib
      dconf
      shared-mime-info
      wayvnc
      wsbridge
      foot
    ]
    ++ lib.optionals needLauncher [fuzzel]
    ++ lib.optionals needBar [scootbarPkg]
    ++ lib.optionals needBg [scootbgPkg]
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
    fontDirectories = with pkgs; [dejavu_fonts];
  };

  # Solid palette-color wallpaper (no third-party images).
  # Dark plum; small valid PNG generated at build time.
  wallpaperPng =
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

  scootConfig = pkgs.writeText "scoot-config.toml" ''
    [layout]
    default_column_width = 1

    [appearance]
    background_color = "#1e1a2b"
    prefer_no_csd = true

    [output]
    [virtual_input]
    enabled = true

    [wallpaper]
    ${lib.optionalString needBg ''        image = "/defaults/wallpaper.png"
            mode = "fill"''}

    [autostart]
    ${lib.optionalString needBar ''      commands = [
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

  barConfig = pkgs.writeText "scoot-bar.toml" ''
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

  footConfig = pkgs.writeText "foot.ini" ''
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

  barLookWrapper = writeShellScriptBin "scoot-bar-look" ''
    exec ${scootbarPkg}/bin/scootbar daemon --font /usr/share/fonts/truetype/DejaVuSans.ttf "$@"
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
    mkdir -p $out/usr/local/bin
    cp ${barLookWrapper}/bin/scoot-bar-look $out/usr/local/bin/scoot-bar-look
    cp ${wtypeShim}/bin/wtype $out/usr/local/bin/wtype
    chmod +x $out/usr/local/bin/scoot-bar-look $out/usr/local/bin/wtype
    cp -r ${../rootfs/s6}/. $out/etc/s6/
    cp ${../rootfs/init} $out/init
    chmod +x $out/init $out/defaults/*.sh
    find $out/etc/s6 -name run -exec chmod +x {} +
  '';

  imageEnv = [
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
