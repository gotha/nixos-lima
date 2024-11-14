{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.lima;
  user = cfg.user;

  # rfc42 settings format
  settingsFormat = pkgs.formats.yaml {};
  # use builtins.toJSON instead of settinsFormat.generate due to architecture change
  configFile = builtins.toFile "lima.yaml" (builtins.toJSON cfg.settings);

  ## bootstrap images -- not critical, will be replaced by nixos-anywhere anyway
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

  ## disable the lima builtin containerd
  containerd = {
    user = false;
    system = false;
  };

  ## filesystem mounts for lima startup
  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";
  fsCiData."${LIMA_CIDATA_MNT}" = {
    device = "${LIMA_CIDATA_DEV}";
    fsType = "auto";
    options = ["ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0"];
  };
  fsRosetta = lib.optionalAttrs cfg.settings.rosetta.enabled {
    # allow switching rosetta off
    # hypervisor is reconfigured before nixos configurtion is applied
    # reboot fails without nofail option, when mountTag does not exist (anymore)
    "${config.virtualisation.rosetta.mountPoint}".options = ["nofail"];
  };

  fileSystems = fsCiData // fsRosetta;
in {
  options.lima = {
    configFile = mkOption {
      type = types.anything;
    };
    hostLimaInternal = mkOption {
      type = types.str;
      default = "192.168.5.2";
      description = "ip on which to reach the host";
    };

    settings = mkOption {
      default = {};
      description = ''
        Lima configuration settings.

        for details see https://github.com/lima-vm/lima/blob/master/examples/default.yaml
      '';
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          # Selected options from lima.yaml. Additional options can be specified
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
          rosetta.enabled = mkOption {
            type = types.bool;
            description = "Enable Rosetta in hypervisor & nixos";
            default = cfg.settings.vmType == "vz";
          };
          video.display = mkOption {
            type = types.str;
            default = "none";
            description = ''
              QEMU display, e.g., "none", "cocoa", "sdl", "gtk", "vnc", "default".
              # Choosing "none" will hide the video output, and not show any window.
              # Choosing "vnc" will use a network server, and not show any window.
              # Choosing "default" will pick the first available of: gtk, sdl, cocoa.
              # 🟢 Builtin default: "none"
            '';
          };

          mounts = mkOption {
            type = types.listOf (types.submodule {
              options = {
                location = mkOption {
                  type = types.str;
                };
                mountPoint = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                writable = mkOption {
                  type = types.bool;
                  default = false;
                };
              };
            });
          };

          portForwards = mkOption {
            type = types.listOf (types.submodule {
              options = {
                guestSocket = mkOption {
                  type = types.str;
                  description = ''
                    "guestSocket" can include these template variables: {{.Home}}, {{.UID}}, {{.User}}, and {{.Param.Key}}.

                    Forwarding requires the lima user to have rw access to the "guestsocket",
                  '';
                };
                hostSocket = mkOption {
                  type = types.str;
                  description = ''
                    "hostSocket" can include {{.Home}}, {{.Dir}}, {{.Name}}, {{.UID}}, {{.User}}, and {{.Param.Key}}.

                    Put sockets into "{{.Dir}}/sock" to avoid collision with Lima internal sockets!
                    Forwarding requires the local user to have rwx access to the directory of the "hostsocket".
                  '';
                };
              };
            });
          };
        };
      };
    };

    user = {
      name = mkOption {
        type = types.str;
        description = "Lima VM user -- Lima requires your local user name";
      };
      sshPubKey = mkOption {
        type = types.str;
        description = "SSH PubKey for password less login into the VM";
      };
    };
    vsockPort = mkOption {
      type = types.ints.between 2222 2222;
      description = ''
        The ssh port on the host system.
        (not sure if it is configurable)
      '';
      default = 2222;
    };
  };
  imports = [./base.nix ./lima_mounts.nix];
  config = {
    lima.configFile = configFile;
    lima.settings = {
      inherit images containerd;
    };

    inherit fileSystems;
    services.openssh.enable = true;
    # user required for limactl start etc. (ssh connectivty & sudo)
    users.groups.${user.name} = {};
    users.users.${user.name} = {
      isNormalUser = true;
      group = user.name;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [user.sshPubKey];
    };
    security.sudo.extraRules = [
      {
        users = [user.name];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"]; # "SETENV" # Adding the following could be a good idea
          }
        ];
      }
    ];

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

    virtualisation.rosetta = lib.mkIf cfg.settings.rosetta.enabled {
      enable = true;
      mountTag = "vz-rosetta";
    };

    networking.hosts = {
      ${cfg.hostLimaInternal} = ["host.lima.internal"];
    };
  };
}
