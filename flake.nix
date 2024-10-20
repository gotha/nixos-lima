{
  description = "NixOS on Lima Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosModules.lima = import ./lima.nix;
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [self.nixosModules.lima];
    };

    packages = self.nixosConfigurations.example.config.lima.packages;
  };
}
