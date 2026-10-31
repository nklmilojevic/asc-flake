{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.asc;
in
{
  options.programs.asc = {
    enable = lib.mkEnableOption "asc - unofficial CLI for App Store Connect";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The asc package to use.";
    };

    telemetry = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether asc may send its pseudonymous usage telemetry, which upstream
        enables by default. When false, sets ASC_TELEMETRY_DISABLED=1.
      '';
    };

    enableBinSymlink = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isLinux;
      description = ''
        Whether to create a symlink at ~/.local/bin/asc.
        Enabled by default on Linux to ensure the binary is in a standard location.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [ cfg.package ];

      sessionVariables = lib.mkIf (!cfg.telemetry) {
        ASC_TELEMETRY_DISABLED = "1";
      };

      file.".local/bin/asc" = lib.mkIf cfg.enableBinSymlink {
        source = "${cfg.package}/bin/asc";
      };
    };
  };
}
