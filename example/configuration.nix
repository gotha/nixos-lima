{
  lib,
  pkgs,
  ...
}: {
  system.stateVersion = "24.11";
  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = map lib.lowPrio [
    pkgs.vim
    pkgs.curl
    pkgs.gitMinimal
  ];
}
