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
    runtimeInputs = builtins.attrValues {
      inherit (pkgsDarwin) lima-bin;
    };
    text = ''
      echo "Welcome to the nixos-lima utility"

      #limactl create --name=${cfg.name} --vm-type ${cfg.vm-type} ./lima.yaml
      limactl start ${cfg.name}

      ssh -p 2222 localhost
    '';
  };

  hostEnv = pkgsDarwin.symlinkJoin {
    name = "nixos-lima";
    paths = builtins.attrValues {
      inherit (pkgsDarwin) lima-bin;
      inherit nixos-lima;
    };
  };
in {
  options.lima = {
    packages = mkOption {
      type = types.attrs; # ${hostSystem}.packages
    };
    name = mkOption {
      type = types.str;
      description = "The name of the VM";
      default = "nixos";
    };
    vm-type = mkOption {
      type = types.enum ["vz"];
      description = "The Virtualization Framework";
      default = "vz";
    };
  };
  config = {
    lima.packages.${hostSystem} = {
      default = hostEnv;
      devShell = pkgsDarwin.mkShell {
        buildInputs = [hostEnv];
      };
    };
  };
}
