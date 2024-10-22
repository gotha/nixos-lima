{
  lib,
  pkgs,
  ...
}: {
  system.stateVersion = "23.11";

  environment.systemPackages = map lib.lowPrio [
    pkgs.vim
    pkgs.curl
    pkgs.gitMinimal
  ];

  services.openssh.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.rosetta.enable = true;
}
