# NixOS for MacOS using Lima-VM

This project combines [NixOS](nixos.org) with [Lima](lima-vm.io) to provide
reproducible NixOS deployments on MacOS with aarch64 architecture.

## Usage

```sh
nix run github:gotha/nixos-lima start
```


or if you want to clone and change the configuration

```sh
git clone https://github.com/gotha/nixos-lima
cd nixos-lima
nix run . start
```

The above command boots a VM (named `mynixos`) using lima and deploys an NixOS configuration.
The default configuration includes docker engine and adds some default volume mounts.

## Credits

Forked from [ciderale/nixos-lima](https://github.com/ciderale/nixos-lima)
most of the original docs still apply, not backwards compatibility is guaranteed or intended.
