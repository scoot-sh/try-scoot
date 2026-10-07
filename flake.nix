{
  description = "try-scoot: smallest fast scoot desktop in the browser (headless scoot + wayvnc + noVNC)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.scoot.url = "github:scoot-sh/scoot";
  inputs.scoot.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, scoot }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      lib = nixpkgs.lib;
      forAllSystems = f: lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        }));
    in
    {
      packages = forAllSystems (pkgs:
        let
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
        in
        {
          inherit image-l0 image-l1 image-try-scoot;
          default = image-try-scoot;
        });

      checks = forAllSystems (pkgs: {
        look-no-third-party = pkgs.runCommand "look-no-third-party-check" { } ''
          lookdir=${./rootfs/looks/default}
          echo "checking $lookdir for third-party images"
          if grep -riE "wallhaven|chillhop|pixabay|unsplash" "$lookdir" 2>/dev/null; then
            echo "third-party image reference found in look" >&2
            exit 1
          fi
          # no binary images committed: only .toml/.ini/.css/.sh allowed
          for f in "$lookdir"/*; do
            case "$f" in
              *.toml|*.ini|*.sh|*.css|*.md|NOTICE*) ;;
              *) echo "unexpected file in look dir: $f" >&2; exit 1 ;;
            esac
          done
          touch $out
        '';
      });
    };
}
