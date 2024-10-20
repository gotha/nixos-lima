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
in {
  options.lima = {
    packages = mkOption {
      type = types.attrs; # ${hostSystem}.packages
    };
  };
  config = {
    lima.packages.${hostSystem}.default = pkgsDarwin.symlinkJoin {
      name = "hello";
      paths = [pkgsDarwin.hello];
    };
  };
}
