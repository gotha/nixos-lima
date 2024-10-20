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

  images = [
    {
      location = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img";
      arch = "x86_64";
    }
    {
      location = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img";
      arch = "aarch64";
    }
  ];
  mounts = [
    {location = "~";}
    {
      location = "/tmp/lima";
      writable = true;
    }
  ];

  lima-configuration = {
    inherit images mounts;
    inherit (cfg) ssh;
  };
  lima-yaml = pkgsDarwin.writeTextFile {
    name = "lima.yaml";
    text = builtins.toJSON lima-configuration;
  };

  nixos-lima = pkgsDarwin.writeShellApplication {
    name = "nixos-lima";
    runtimeInputs = builtins.attrValues {
      inherit (pkgsDarwin) lima-bin nixos-anywhere;
    };
    text = ''
      echo "Welcome to the nixos-lima utility"
      set -x

      SSH_PORT=${builtins.toString cfg.ssh.localPort}
      if ! limactl list ${cfg.name}; then
        limactl create --name=${cfg.name} --vm-type ${cfg.vm-type} ${lima-yaml}
        ssh-keygen -R "[localhost]:$SSH_PORT"
        limactl start ${cfg.name}

        nixos-anywhere --flake ../nixos-utm#utm ale@localhost -p $SSH_PORT --post-kexec-ssh-port $SSH_PORT --build-on-remote

        echo "# wait till ssh server is up-and-running: ssh-keyscan gets a key"
        while ! ssh-keyscan -4 -p $SSH_PORT localhost; do sleep 2; done
      fi
      if ! limactl list ${cfg.name} | grep Running; then
        limactl start ${cfg.name}
      fi

      ssh -p $SSH_PORT root@localhost ## user depends on nixos configuration
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
    ssh.localPort = mkOption {
      type = types.int;
      description = "The ssh port on the host system";
      default = 2222;
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
