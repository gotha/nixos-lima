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
  nix.settings.experimental-features = ["nix-command" "flakes"];

  services.openssh.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.rosetta.enable = true;
}
