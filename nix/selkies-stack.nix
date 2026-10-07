# Selkies streaming stack for the `:selkies` variant image.
#
# Fresh MIT work for this repo. It packages upstream `selkies-project/selkies`
# 2.0.0 (MPL-2.0, unmodified) from its PyPI wheel together with the capture
# wheels it was released against (`pixelflux`/`pcmflux` 2.1.0, wheel-only
# upstream). The dependency list below is derived from the wheel itself
# (module imports plus its METADATA runtime requirements); packages nothing
# in that closure imports are left out on purpose and get added back only if
# a build or smoke test names them.
#
# Two deliberate trade-offs for this first variant round:
# - The web client comes from the wheel's bundled build (`selkies/selkies_web`),
#   so no npm build runs here and no lockfiles are vendored. Reproducibility
#   still holds: the wheel is a fixed-output fetch pinned by hash.
# - Only the Python the pinned nixpkgs carries is supported (3.14 here); other
#   interpreters fail with a message naming the missing wheel, not a 404.
{
  lib,
  pkgs,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  python3,
  wayland,
  libglvnd,
  mesa,
  libgbm,
  libva,
  libdrm,
  libxkbcommon,
  pixman,
  libGL,
  libx11,
  libxext,
  libice,
  libsm,
  zlib,
  pulseaudio,
}: let
  inherit (python3.pkgs) buildPythonPackage;
  python = python3;
  pyVer = lib.versions.majorMinor python.version;

  pickWheel = name: version: wheels: let
    perPy = wheels.${pyVer} or (throw "${name}: no wheel for python ${pyVer} (only ${lib.concatStringsSep ", " (lib.attrNames wheels)} are pinned)");
    perSys = perPy.${stdenv.hostPlatform.system} or (throw "${name}: no wheel for python ${pyVer} on ${stdenv.hostPlatform.system}");
  in
    perSys;

  pixelfluxWheel = pickWheel "pixelflux" "2.1.0" {
    "3.14" = {
      aarch64-linux = {
        file = "pixelflux-2.1.0-cp314-cp314-manylinux_2_28_aarch64.whl";
        url = "https://files.pythonhosted.org/packages/8e/ab/964a7cdb7b6add178c97acb5fbc4b187df14fcf981a88167e065e7c2121b/pixelflux-2.1.0-cp314-cp314-manylinux_2_28_aarch64.whl";
        hash = "sha256-mWDIBEVCZdfiWTXvdnUDKQl4GgMrUHiSh8BLF5fr7gQ=";
      };
      x86_64-linux = {
        file = "pixelflux-2.1.0-cp314-cp314-manylinux_2_28_x86_64.whl";
        url = "https://files.pythonhosted.org/packages/55/e2/b3d4ebf6180ed84c520aafe204a36fcda28d60559caab2e3be889d4eadef/pixelflux-2.1.0-cp314-cp314-manylinux_2_28_x86_64.whl";
        hash = "sha256-pPP7UvXi3sA8mxU5rHUMGdQ6BNALTedEBUJgKS0doPI=";
      };
    };
  };

  pcmfluxWheel = pickWheel "pcmflux" "2.1.0" {
    "3.14" = {
      aarch64-linux = {
        file = "pcmflux-2.1.0-cp314-cp314-manylinux_2_28_aarch64.whl";
        url = "https://files.pythonhosted.org/packages/e2/48/3257067b3866e4e3910918c8f16dcc2d1fbb13ae7dab588e0840b48584f7/pcmflux-2.1.0-cp314-cp314-manylinux_2_28_aarch64.whl";
        hash = "sha256-UbJmp2baaT9pTUtIaHYTTxmJ5f64lH8JHrIok9xZRhw=";
      };
      x86_64-linux = {
        file = "pcmflux-2.1.0-cp314-cp314-manylinux_2_28_x86_64.whl";
        url = "https://files.pythonhosted.org/packages/89/95/631255b607ae11f3425d2aace88e041d2d34199c087184483bdba9494095/pcmflux-2.1.0-cp314-cp314-manylinux_2_28_x86_64.whl";
        hash = "sha256-6xr+EOFNPTiIpAqkAaz8EWv6AICrm4B/Ftt/QPFCRBE=";
      };
    };
  };

  # Libraries the capture wheels link or dlopen by soname. autoPatchelf
  # rewires the linked ones; the wrapper on the `selkies` program below
  # carries the same set so dlopen-by-soname resolves at runtime too.
  captureLibs = [
    stdenv.cc.cc.lib
    wayland
    libglvnd
    mesa
    libgbm
    libva
    libdrm
    libxkbcommon
    pixman
    libGL
    zlib
    libx11
    libxext
  ];

  pixelflux = buildPythonPackage {
    pname = "pixelflux";
    version = "2.1.0";
    format = "wheel";
    src = fetchurl {
      inherit (pixelfluxWheel) url hash;
      name = pixelfluxWheel.file;
    };
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = captureLibs;
    runtimeDependencies = captureLibs ++ [pulseaudio];
    pythonImportsCheck = ["pixelflux"];
    meta = with lib; {
      description = "Selkies screen capture and video encoding module";
      homepage = "https://github.com/selkies-project/pixelflux";
      license = licenses.mpl20;
      platforms = ["x86_64-linux" "aarch64-linux"];
      sourceProvenance = [sourceTypes.binaryNativeCode];
    };
  };

  pcmflux = buildPythonPackage {
    pname = "pcmflux";
    version = "2.1.0";
    format = "wheel";
    src = fetchurl {
      inherit (pcmfluxWheel) url hash;
      name = pcmfluxWheel.file;
    };
    nativeBuildInputs = [autoPatchelfHook];
    # The wheel vendors its audio dependencies under pcmflux.libs, but that
    # bundle stops at libXi/libXtst/libpulse: their own X11/ICE/SM linkage
    # still has to come from the store (measured: autoPatchelf names exactly
    # libX11, libXext, libICE, libSM as unsatisfied without these).
    buildInputs = [stdenv.cc.cc.lib libx11 libxext libice libsm];
    runtimeDependencies = [libx11 libxext libice libsm pulseaudio];
    pythonImportsCheck = ["pcmflux"];
    meta = with lib; {
      description = "Selkies audio capture and Opus encoding module";
      homepage = "https://github.com/selkies-project/pcmflux";
      license = licenses.mpl20;
      platforms = ["x86_64-linux" "aarch64-linux"];
      sourceProvenance = [sourceTypes.binaryNativeCode];
    };
  };

  selkies = python.pkgs.buildPythonApplication {
    pname = "selkies";
    version = "2.0.0";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/52/f8/91f5be8115042e7c3fbe1e3a6167b6dde28dc1e4782ec0920adf3468ba0d/selkies-2.0.0-py3-none-any.whl";
      name = "selkies-2.0.0-py3-none-any.whl";
      hash = "sha256-8nd+dNGR4rUGMZDUC/xt8A16d5MGIOAEinkmfyEcvq0=";
    };
    dependencies = with python.pkgs; [
      aiohttp
      aiofiles
      cffi
      cryptography
      dnspython
      google-crc32c
      msgpack
      nvidia-ml-py
      pillow
      prometheus-client
      psutil
      pulsectl
      pulsectl-asyncio
      pyee
      pylibsrtp
      pyopenssl
      uvloop
      watchdog
      pixelflux
      pcmflux
    ];
    pythonRelaxDeps = true;
    doCheck = false;
    # Import the transport module too, not just the top package: that is what
    # pulls pixelflux/pcmflux and the rest of the runtime closure in, so a
    # missing dependency fails the build here instead of the container later.
    pythonImportsCheck = ["selkies" "selkies.websockets_mode" "pixelflux" "pcmflux"];
    # pixelflux/pcmflux and selkies' own input path resolve several graphics,
    # input, and audio libraries by soname only at runtime; carry them on the
    # program's library path so the container needs no global ldconfig state.
    makeWrapperArgs = [
      "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (captureLibs ++ [pulseaudio])}"
    ];
    meta = with lib; {
      description = "Low-latency Linux remote desktop streaming platform";
      homepage = "https://github.com/selkies-project/selkies";
      license = licenses.mpl20;
      mainProgram = "selkies";
    };
  };
in {
  inherit pixelflux pcmflux selkies;
}
