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
      look-no-third-party = pkgs.runCommand "look-no-third-party-check" {} ''
        lookdir=${./rootfs/looks/default}
        echo "checking $lookdir for third-party images"
        if grep -riE "wallhaven|chillhop|pixabay|unsplash" "$lookdir" 2>/dev/null; then
          echo "third-party image reference found in look" >&2
          exit 1
        fi
        # no binary images committed: only .toml/.ini/.css/.sh allowed.
        # NOTE: match the basename, not the full store path: $lookdir is a
        # /nix/store path, so "$f" never starts with NOTICE.
        for f in "$lookdir"/*; do
          case "$(basename "$f")" in
            *.toml|*.ini|*.sh|*.css|*.md|NOTICE*) ;;
            *) echo "unexpected file in look dir: $f" >&2; exit 1 ;;
          esac
        done
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
