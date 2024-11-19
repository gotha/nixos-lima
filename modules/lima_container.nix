{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
  dockerSocketLocation = "sock/docker.sock";
in {
  options.lima.hostDockerSocketLocation = lib.mkOption {
    type = lib.types.str;
    default = "${cfg.vmConfigDir}/${dockerSocketLocation}";
    description = "location of the host exposed docker/podman socket";
  };
}
