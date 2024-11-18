{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
  dockerSocketLocation = "sock/docker.sock";
  hostDockerSocketLocation = "{{.Dir}}/${dockerSocketLocation}";
  hostDockerSocketInGuest = "/Users/${cfg.user.name}/.lima/${cfg.vmName}/${dockerSocketLocation}";
in
  lib.mkIf config.virtualisation.docker.enable {
    # lima user must be in group docker
    users.users.${cfg.user.name}.extraGroups = ["docker"];
    lima.settings.portForwards = [
      {
        guestSocket = "/run/docker.sock";
        hostSocket = hostDockerSocketLocation;
      }
    ];
    # ensure that test container finds the docker socket where it is on host
    virtualisation.docker.listenOptions = [hostDockerSocketInGuest];
    networking.hosts.${cfg.hostLimaInternal} = ["host.docker.internal"];
  }
