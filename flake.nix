{
  description = "asc - unofficial CLI for App Store Connect";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # nixpkgs-unstable (26.11) dropped x86_64-darwin, so instantiating pkgs
      # for it throws. sources.json still tracks the Intel macOS asset, so the
      # system can be re-added here whenever nixpkgs supports it again.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        {
          packages = {
            asc = pkgs.callPackage ./package.nix { };
            default = pkgs.callPackage ./package.nix { };
          };
        };

      flake = {
        # Replaces nixpkgs' unrelated `asc` (a turn-based strategy game).
        overlays.default = final: _prev: {
          asc = final.callPackage ./package.nix { };
        };

        homeManagerModules.default = import ./home-module.nix;
      };
    };
}
