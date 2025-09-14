{ config, ... }: {
  # ensure docker socket location on host does exist in guest too
  # thus avoids setting TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE environment variable
  # still requires setting DOCKER_HOST, unless location is /var/run/docker.sock
  # https://java.testcontainers.org/supported_docker_environment/#podman
  fileSystems."${config.lima.vmConfigDir}" = {
    # don't create docker.sock on host-volume mount (not allowed)
    # ensure a empty space is available to place the docker socket
    device = "none";
    fsType = "tmpfs";
    options = [ "nofail" "defaults" ];
  };
}
