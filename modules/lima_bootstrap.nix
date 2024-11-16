{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
  user = cfg.user;

  options.lima = with lib; {
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
    cidata = mkOption {
      type = types.str;
      default = "/mnt/lima-cidata";
      description = "location where cidata is mounted";
    };
    hostLimaInternal = mkOption {
      type = types.str;
      default = "192.168.5.2";
      description = "ip on which to reach the host";
    };
  };
in {
  inherit options;
  config = {
    fileSystems."${cfg.cidata}" = {
      device = "/dev/disk/by-label/cidata";
      fsType = "auto";
      options = ["ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0"];
    };
    systemd.services.lima-init = {
      description = "lima-init for cloud-init like mutable setup";
      wantedBy = ["multi-user.target"];
      script = ''
        cp "${cfg.cidata}"/meta-data /run/lima-ssh-ready
        cp "${cfg.cidata}"/meta-data /run/lima-boot-done
      '';
      after = ["network-pre.target"];

      restartIfChanged = true;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.tmpfiles.rules = [
      # ensure that /bin/bash exists
      (lib.mkIf true "L /bin/bash - - - - /run/current-system/sw/bin/bash")
    ];

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
    networking.hosts = {
      ${cfg.hostLimaInternal} = ["host.lima.internal"];
    };
  };
}
