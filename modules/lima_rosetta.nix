{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
in {
  fileSystems = lib.optionalAttrs cfg.settings.rosetta.enabled {
    # allow switching rosetta off
    # hypervisor is reconfigured before nixos configurtion is applied
    # reboot fails without nofail option, when mountTag does not exist (anymore)
    "${config.virtualisation.rosetta.mountPoint}".options = ["nofail"];
  };

  virtualisation.rosetta = lib.mkIf cfg.settings.rosetta.enabled {
    enable = true;
    mountTag = "vz-rosetta";
  };
}
