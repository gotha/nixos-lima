{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
  dockerSocketLocation = "sock/docker.sock";
  hostDockerSocketLocation = "${cfg.vmConfigDir}/${dockerSocketLocation}";
in
  lib.mkIf config.virtualisation.podman.enable {
    users.users.${cfg.user.name}.extraGroups = ["podman"];
    lima.settings.portForwards = [
      {
        guestSocket = "/run/podman/podman.sock"; # user must be in group docker
        hostSocket = hostDockerSocketLocation;
      }
    ];
    networking.hosts.${cfg.hostLimaInternal} = ["host.docker.internal"];
    virtualisation.podman.dockerCompat = true;
    virtualisation.podman.dockerSocket.enable = true;
    systemd.sockets.podman.socketConfig.Symlinks = [
      hostDockerSocketLocation
      "/var/run/docker.sock"
    ];
  }
