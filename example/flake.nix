{
  description = "NixOS on Lima";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable-small";
    nixos-lima.url = "github:ciderale/nixos-lima";
    nixos-lima.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixos-lima,
    nixpkgs,
    ...
  }: let
  in {
    # an example for testing purposes
    nixosConfigurations.mynixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        nixos-lima.nixosModules.lima
        nixos-lima.nixosModules.disk-default
        nixos-lima.nixosModules.docker
        nixos-lima.nixosModules.podman
        nixos-lima.nixosModules.impure-config
        ./lima-settings.nix
        ./configuration.nix
      ];
    };

    devShells = nixos-lima.devShells;
    packages = nixos-lima.packages;
  };
}
