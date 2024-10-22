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
    {location = "/Users/ale";}
    {
      location = "/tmp/lima";
      writable = true;
    }
  ];

  fs =
    lib.lists.imap0 (i: {
      location,
      writable ? false,
    }: {
      name = location;
      value.device = "mount${toString i}";
      value.fsType = "virtiofs";
    })
    mounts;
  portForwards = [
    {
      # TODO: conifgure via nixos submodul
      # sockets/folder must be read/writable by the owning user (in host or guest)
      # "guestSocket" can include these template variables: {{.Home}}, {{.UID}}, and {{.User}}.
      # "hostSocket" can include {{.Home}}, {{.Dir}}, {{.Name}}, {{.UID}}, and {{.User}}.
      # NOTE 1: more details in lima-default=template
      # NOTE 2: exposed via ssh port-forward mechanism
      # NOTE 3: also tcp forwards configuration possible
      guestSocket = "/run/docker.sock"; # user must be in group docker
      hostSocket = "{{.Dir}}/sock/docker.sock";
    }
  ];

  lima-configuration = {
    inherit images mounts portForwards;
    inherit (cfg) ssh vmType rosetta;
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
    vsockPort = mkOption {
      type = types.ints.between 2222 2222;
      description = ''
        The ssh port on the host system.
        (not sure if it is configurable)
      '';
      default = 2222;
    };
    rosetta.enabled = mkOption {
      type = types.bool;
      description = "Enable Rosetta in hypervisor";
      default = config.virtualisation.rosetta.enable;
    };
  };
  imports = [
    {fileSystems = lib.listToAttrs fs;}
  ];
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
        ExecStart = "${LIMA_CIDATA_MNT}/lima-guestagent daemon --vsock-port ${toString cfg.vsockPort}";
        Restart = "on-failure";
      };
    };

    virtualisation.rosetta.mountTag = "vz-rosetta";
  };
}
