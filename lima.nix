{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.lima;
  hostSystem = "aarch64-darwin";
  pkgsDarwin = import pkgs.path {system = hostSystem;};

  nixos-lima = pkgsDarwin.writeShellApplication {
    name = "nixos-lima";
    text = ''
      echo "Welcome to the nixos-lima utility"
    '';
  };
in {
  options.lima = {
    packages = mkOption {
      type = types.attrs; # ${hostSystem}.packages
    };
  };
  config = {
    lima.packages.${hostSystem}.default = pkgsDarwin.symlinkJoin {
      name = "nixos-lima";
      paths = builtins.attrValues {
        inherit (pkgsDarwin) lima-bin;
        inherit nixos-lima;
      };
    };
  };
}
