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
  }: {
    nixosModules.lima = import ./lima.nix;
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        self.nixosModules.lima
        inputs.disko.nixosModules.disko
        ./example/base.nix
        ./example/hardware-configuration.nix
        ./example/disk-config.nix
        ./example/configuration.nix
        {lima.name = "mynixos";}
      ];
    };

    # TODO: this is not very convenient, improve usability
    packages = self.nixosConfigurations.example.config.lima.packages;
    devShells.aarch64-darwin.default = self.nixosConfigurations.example.config.lima.packages.aarch64-darwin.devShell;
  };
}
