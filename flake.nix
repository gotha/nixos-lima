{
  description = "NixOS on Lima Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    disko.url = "github:nix-community/disko";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    system = "aarch64-linux";
    hostSystem = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages."${hostSystem}";
    packages = pkgs.callPackages ./nixos-lima.nix {};
  in {
    packages.aarch64-darwin = packages;
    devShells.aarch64-darwin.default = pkgs.mkShell {
      buildInputs = builtins.attrValues packages;
    };

    # the lima configuration module
    nixosModules.lima = import ./lima.nix;

    # additional convenience modules
    nixosModules.disk-default = {
      imports = [inputs.disko.nixosModules.disko ./example/disk-config.nix];
    };
    nixosModules.docker = import ./example/docker.nix;

    # an example for testing purposes
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        self.nixosModules.lima
        self.nixosModules.docker
        self.nixosModules.disk-default
        ./example/configuration.nix
        {
          lima.user.name = "ale";
          lima.user.sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKyKsE4eCn8BDnJZNmFttaCBmVUhO73qmhguEtNft6y";
          lima.settings.mounts = [
            {location = "/Users/ale";}
            {
              location = "/tmp/lima";
              writable = true;
            }
          ];
        }
      ];
    };
  };
}
