{ config, lib, ... }:
let cfg = config.lima;
in {
  options.lima = {
    dockerVmHostIp = lib.mkOption {
      type = lib.types.str;
      default = "172.17.0.1";
      description = "The IP on which a container can reach the VM host system";
    };
    hostDnsNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "host.docker.internal" ];
      description = "DNS Names by which to reach the host system (not the VM)";
    };
  };
  config = {
    # enable local dns to inject into docker/podman containers
    services.dnsmasq.enable = true;
    #services.dnsmasq.resolveLocalQueries = true;
    #services.dnsmasq.settings.log-queries = true;
    virtualisation.docker.extraOptions = "--dns=${cfg.dockerVmHostIp}";
    networking.hosts.${cfg.hostLimaInternal} = cfg.hostDnsNames;
  };
}
