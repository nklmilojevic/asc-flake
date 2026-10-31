# asc Nix Flake

A Nix flake that packages [asc](https://asccli.sh), an unofficial CLI for
App Store Connect ([rorkai/App-Store-Connect-CLI](https://github.com/rorkai/App-Store-Connect-CLI)).

## Features

- Pre-built binaries from official GitHub releases — no Go compile
- Multi-platform support: Linux (x86_64, aarch64) and macOS (x86_64, aarch64)
- Automatic hourly updates via GitHub Actions, checked against upstream's
  `asc_<version>_checksums.txt`
- Home Manager module that turns asc's default-on telemetry off

## Why not nixpkgs?

`nixpkgs#asc` is an unrelated turn-based strategy game, and asc isn't packaged
there. The overlay below replaces that attribute.

The Linux artifacts are static Go binaries and the macOS ones link only system
frameworks, so they are installed byte-identical (keeping the Developer ID
signature intact).

## Usage

### Run directly

```bash
nix run github:nklmilojevic/asc-flake -- --version
```

### Install with nix profile

```bash
nix profile install github:nklmilojevic/asc-flake
```

### Use the overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    asc.url = "github:nklmilojevic/asc-flake";
  };

  outputs = { nixpkgs, asc, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ asc.overlays.default ];
          environment.systemPackages = [ pkgs.asc ];
        })
      ];
    };
  };
}
```

### Home Manager module

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    asc.url = "github:nklmilojevic/asc-flake";
  };

  outputs = { nixpkgs, home-manager, asc, ... }: {
    homeConfigurations.myuser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      modules = [
        asc.homeManagerModules.default
        {
          programs.asc.enable = true;
          # programs.asc.telemetry = true;  # opt back in to upstream telemetry
        }
      ];
    };
  };
}
```

Unless `programs.asc.telemetry` is true, the module sets
`ASC_TELEMETRY_DISABLED=1` in the session environment.

## Version Updates

This flake is automatically updated hourly via GitHub Actions. The workflow:

1. Checks GitHub releases for new stable versions
2. Downloads binaries for all platforms and checks them against upstream's checksums
3. Computes SRI hashes
4. Updates `sources.json` and commits

Current version is tracked in [sources.json](./sources.json).

## Manual Update

To manually trigger an update:

1. Go to Actions > "Update asc version" > "Run workflow"
2. Or run locally: `bash update.sh`

## Development

Enter the dev shell:

```bash
cd dev && nix develop
```

## License

The Nix code in this repository is provided under the MIT license.
asc itself is licensed under the [MIT License](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/LICENSE).
