{config, ...}: let
  dockerSocketLocation = "sock/docker.sock";
  limaVmName = "mynixos";
in {
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  virtualisation.podman.dockerSocket.enable = true;
  lima.settings.portForwards = [
    {
      guestSocket = "/run/podman/podman.sock"; # user must be in group docker
      hostSocket = "{{.Dir}}/${dockerSocketLocation}";
    }
  ];
  users.users.${config.lima.user.name}.extraGroups = ["docker" "podman"];
  networking.hosts.${config.lima.hostLimaInternal} = ["host.docker.internal"];
  systemd.sockets.podman.socketConfig.Symlinks = [
    "/Users/${config.lima.user.name}/.lima/${limaVmName}/${dockerSocketLocation}"
    "/var/run/docker.sock"
  ];
}
