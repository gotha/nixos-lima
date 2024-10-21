{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.lima;
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
    inherit (cfg) ssh vmType;
  };
  lima-yaml = builtins.toFile "lima.yaml" (builtins.toJSON lima-configuration);
in {
  options.lima = {
    yaml = mkOption {
      type = types.anything;
    };
    name = mkOption {
      type = types.str;
      description = "The name of the VM";
      default = "nixos";
    };
    vmType = mkOption {
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
    lima.yaml = lima-yaml;
  };
}
