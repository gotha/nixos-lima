{ config, lib, ... }:
with lib;
let
  cfg = config.lima;

  options.lima = {
    vsockPort = mkOption {
      type = types.ints.between 2222 2222;
      description = ''
        The ssh port on the host system.
        (not sure if it is configurable)
      '';
      default = 2222;
    };
  };
in {
  inherit options;
  config = {
    systemd.services.lima-guestagent = {
      enable = true;
      description = "lima-guestagent for port forwarding";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        # this get everything into the VM -- even qemu, not just the guestagent
        # ExecStart = "${pkgs.lima-bin}/share/lima/lima-guestagent.Linux-aarch64 daemon";
        ExecStart = "${cfg.cidata}/lima-guestagent daemon --vsock-port ${
            toString cfg.vsockPort
          }";
        Restart = "on-failure";
      };
    };
  };
}
