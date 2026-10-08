{
  description = "try-scoot: smallest fast scoot desktop in the browser (headless scoot + wayvnc + noVNC)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.scoot.url = "github:scoot-sh/scoot";
  inputs.scoot.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
    nixpkgs,
    scoot,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    lib = nixpkgs.lib;
    forAllSystems = f:
      lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        }));
  in {
    packages = forAllSystems (pkgs: let
      scootPkg = scoot.packages.${pkgs.stdenv.hostPlatform.system}.scoot;
      scootbgPkg = scoot.packages.${pkgs.stdenv.hostPlatform.system}.scootbg;
      scootbarPkg = scoot.packages.${pkgs.stdenv.hostPlatform.system}.scootbar;
      mkImage = pkgs.callPackage ./nix/image.nix {
        inherit scootPkg scootbgPkg scootbarPkg;
        scootFlake = scoot;
      };
      image-l0 = mkImage {
        name = "try-scoot-l0";
        title = "try-scoot L0";
        withBar = false;
        withBg = false;
        withLauncher = false;
      };
      image-l1 = mkImage {
        name = "try-scoot-l1";
        title = "try-scoot L1";
        withBar = true;
        withBg = true;
        withLauncher = true;
      };
      image-try-scoot = mkImage {
        name = "try-scoot";
        title = "try-scoot";
        withBar = true;
        withBg = true;
        withLauncher = true;
        withLook = true;
      };
      # Selkies variant stack (second, opt-in image; the default above is
      # untouched by everything below).
      selkiesStack = pkgs.callPackage ./nix/selkies-stack.nix {};
      selkies = selkiesStack.selkies;
      mkSelkiesImage = pkgs.callPackage ./nix/image-selkies.nix {
        inherit scootPkg scootbgPkg scootbarPkg selkiesStack;
        scootFlake = scoot;
      };
      image-selkies-l0 = mkSelkiesImage {
        name = "try-scoot-selkies-l0";
        title = "try-scoot Selkies L0";
        withDesktop = false;
        withLook = false;
      };
      image-try-scoot-selkies = mkSelkiesImage {
        name = "try-scoot-selkies";
        title = "try-scoot Selkies";
        withDesktop = true;
        withLook = true;
      };
    in {
      inherit image-l0 image-l1 image-try-scoot selkies image-selkies-l0 image-try-scoot-selkies;
      default = image-try-scoot;
    });

    checks = forAllSystems (pkgs: {
      look-no-third-party = pkgs.runCommand "look-no-third-party-check" {nativeBuildInputs = [pkgs.coreutils];} ''
        echo "checking repo for third-party images"
        if grep -riE "wallhaven|chillhop|pixabay|unsplash" ${./nix} ${./rootfs} 2>/dev/null; then
          echo "third-party image reference found in nix/rootfs" >&2
          exit 1
        fi
        # No binary images vendored in this repo: the session wallpaper
        # comes from the scoot flake input (see nix/ginger-night.nix), not
        # from a file committed here. Any png/jpg committed under rootfs
        # is rejected so a third-party wallpaper cannot slip in as a file.
        if find ${./rootfs} -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit | grep -q .; then
          echo "unexpected image file under rootfs (wallpaper comes from the scoot input)" >&2
          find ${./rootfs} -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) >&2
          exit 1
        fi
        # The one allowed wallpaper: ginger-night's file from the scoot
        # input, pinned by name and by sha256. A scoot bump that swaps the
        # wallpaper (or a third-party image under that path) fails here
        # until the allowlist is deliberately updated.
        expected_name="wallpaper.png"
        expected_sha="57d2e07f79f2c46a7e4165b209bbd24948f2ebfbfc653e0e584de6a1a1318f58"
        look_png="${scoot}/docs/examples/ginger-night/wallpaper.png"
        actual_name="$(basename "$look_png")"
        actual_sha="$(sha256sum "$look_png" | cut -d' ' -f1)"
        echo "ginger-night wallpaper: $actual_name $actual_sha"
        if [ "$actual_name" != "$expected_name" ]; then
          echo "wallpaper name drifted: $actual_name != $expected_name (update flake.nix allowlist)" >&2
          exit 1
        fi
        if [ "$actual_sha" != "$expected_sha" ]; then
          echo "wallpaper sha256 drifted: $actual_sha != $expected_sha (update flake.nix allowlist)" >&2
          exit 1
        fi
        touch $out
      '';
    });

    formatter =
      nixpkgs.lib.genAttrs
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
      (system: let
        p = import nixpkgs {inherit system;};
      in
        # Bare alejandra reads stdin when invoked with no path args, so
        # `nix fmt -- --check` failed with "unexpected end of file" while the
        # files themselves were clean. The wrapper defaults to the tree root
        # when the caller names no path, so both `nix fmt` and
        # `nix fmt -- --check` operate on `.`.
        p.writeShellScriptBin "alejandra" ''
          has_path=0
          for a in "$@"; do
            case "$a" in
              -*) ;;
              *) has_path=1; break ;;
            esac
          done
          if [ "$has_path" = 0 ]; then
            exec ${p.alejandra}/bin/alejandra "$@" .
          else
            exec ${p.alejandra}/bin/alejandra "$@"
          fi
        '');
  };
}
