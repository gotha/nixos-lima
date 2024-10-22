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
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKyKsE4eCn8BDnJZNmFttaCBmVUhO73qmhguEtNft6y"
  ];

  # user required for limactl start
  users.users.ale.isNormalUser = true;
  users.users.ale.group = "ale";
  users.users.ale.extraGroups = ["wheel" "docker"];
  users.groups.ale = {};
  users.users.ale.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKyKsE4eCn8BDnJZNmFttaCBmVUhO73qmhguEtNft6y"
  ];
  security.sudo.extraRules = [
    {
      users = ["ale"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"]; # "SETENV" # Adding the following could be a good idea
        }
      ];
    }
  ];

  virtualisation.docker.enable = true;
  virtualisation.rosetta.enable = true;
}
