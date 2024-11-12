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

  # ensure docker socket location on host does exist in guest too
  # thus avoids setting TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE environment variable
  # still requires setting DOCKER_HOST, unless location is /var/run/docker.sock
  # https://java.testcontainers.org/supported_docker_environment/#podman
  fileSystems."/Users/${config.lima.user.name}/.lima/mynixos" = {
    # don't create docker.sock on host-volume mount (not allowed)
    # ensure a empty space is available to place the docker socket
    device = "none";
    fsType = "tmpfs";
    options = ["nofail" "defaults"];
  };
  systemd.sockets.podman.socketConfig.Symlinks = [
    "/Users/${config.lima.user.name}/.lima/${limaVmName}/${dockerSocketLocation}"
    "/var/run/docker.sock"
  ];
}
