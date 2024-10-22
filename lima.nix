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
    containerd = {
      user = false;
      system = false;
    };
  };
  lima-yaml = builtins.toFile "lima.yaml" (builtins.toJSON lima-configuration);

  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";
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

    fileSystems."${LIMA_CIDATA_MNT}" = {
      device = "${LIMA_CIDATA_DEV}";
      fsType = "auto";
      options = ["ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0"];
    };

    systemd.tmpfiles.rules = [
      # ensure that /bin/bash exists
      (mkIf true "L /bin/bash - - - - /run/current-system/sw/bin/bash")
    ];

    systemd.services.lima-init = {
      description = "lima-init for cloud-init like mutable setup";
      wantedBy = ["multi-user.target"];
      script = ''
        cp "${LIMA_CIDATA_MNT}"/meta-data /run/lima-ssh-ready
        cp "${LIMA_CIDATA_MNT}"/meta-data /run/lima-boot-done
      '';
      after = ["network-pre.target"];

      restartIfChanged = true;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.lima-guestagent = {
      enable = true;
      description = "lima-guestagent for port forwarding";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "simple";
        # this get everything into the VM -- even qemu, not just the guestagent
        # ExecStart = "${pkgs.lima-bin}/share/lima/lima-guestagent.Linux-aarch64 daemon";
        ExecStart = "${LIMA_CIDATA_MNT}/lima-guestagent daemon --vsock-port 2222";
        Restart = "on-failure";
      };
    };
  };
}
