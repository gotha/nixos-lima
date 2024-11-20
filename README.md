# NixOS for MacOS using Lima-VM

This project combines [NixOS](nixos.org) with [Lima](lima-vm.io) to provide
reproducible NixOS deployments on MacOS with aarch64 architecture.

## Usage (off-the-shelf)

```
nix run github:ciderale/nixos-lima start
```

The above command boots a VM using lima and deploys an NixOS configuration.
The configuration includes docker engine and adds some default volume mounts.

## Container support

The default `nixos-lima` configuration includes a docker installation.
The shell rc script `~/.lima/mynixos.shrc` will setup the DOCKER_HOST
and CONTAINER_HOST variable and add `docker` to your PATH variable.
You could add this to your .zprofile startup script for example.

In addition to lima-vm.io's port forwarding, `nixos-lima` can listens to the
docker event stream and thus provide port mapping more promptly than via polling.

```
nix run github:ciderale/nixos-lima portmapperd
```

The subcommand `nix run github:ciderale/nixos-lima full` combines `start`
and `portmapperd` in one. Stopping `full` with ctrl-c currently also stops
the virtual machine.

## Adhoc customization using NIXOS_LIMA_IMPURE_CONFIG

The system configurations can extended by pointing the NIXOS_LIMA_IMPURE_CONFIG
environment variable to additional configuration files.

```
NIXOS_LIMA_IMPURE_CONFIG=sizing.nix,mounts.nix nix run github:ciderale/nixos-lima start
```

The configuration includes all [nixos options](https://search.nixos.org/options)
as well as the [lima-vm configurations](https://lima-vm.io).
For example, the following configuration defines cpu, memory, and disk size
```
{ lima.settings = { cpus = 8; memory = "8GB"; disk = "60GB"; }; }
```
or map additional filesystem location(s) from host to guest
```
{ lima.settings.mounts = [ { location = "/host/folder/data"; mountPoint = "/data"; } ]; }
```
For more examples see "example/lima-settings.nix". It's worth noting that the options
under `lima.settings` correspond to lima templates and are used to the generate the 
`lima.yaml` configuration.

Changes are applied by re-running `nixos-lima start`. Note that changes to `lima.settings`
result in a restart of the VM for those changes to take effect. Normal nixos options 
changes are applied by means of `nixos-rebuild switch` and don't require a VM restart.
`nixos-lima` takes care of the entire process.

Technically, the referenced configuration files are merged into the existing
configuration using the nix modules `{ imports = [ ... ]; }` expression.
Multiple files may be referenced (separated by comma) by absolute path or
relative to the current working directory.


## Usage with advanced customisation

More advanced configuration are better versioned explicitly using git. The
`nixos-lima` repository provides a nix flake template to start building the own
configuration. This approach is more flexible and allows to remove configuration
present in the example configuration.

```
# create a new repository to track your changes
cd some/path && mkdir mynixos && cd mynixos
nix flake init -t github:ciderale/nixos-lima

# deploy (and update) the configuration
nix run .#nixos-lima -- mynixos start

# get shell access to your machine
nix run .#nixos-lima -- mynixos ssh
```

# Related work

## https://lima-vm.io

As the name suggests, `nixos-lima` uses lima-vm.io as its underlying
virtualisation system. `nixos-lima` also benefits from the port- and
volume-mapping functionality provided by lima. Configuration in lima is done
via yaml templates and the linux vm is setup using cloud-init scripts.

In contrast, `nixos-lima` has a minimal cloud-init setup and instead relies on
NixOS configurations. NixOS provides a modular configuration system with many
pre-configured services. Moreover, NixOS generates highly reproducible
deployments.

## https://github.com/kasuboski/nixos-lima

"kasuboski/nixos-lima" also aims for running nixos on lima, hence the same
name. A key difference is how the two projects bootstrap a system.

"kasuboski/nixos-lima" uses the nixos-generator project to build an initial
image. This approach requires a linux system running nix. For example, a
lima-vm can be used with cloud-init script to setup nix.

In contrast, `nixos-lima` uses
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to deploy
NixOS onto a freshly started lima-vm. In other words, instead of starting a vm
to build an image, which is then used for a second vm, `nixos-lima` starts one
vm and overwrites that system with the nixos configuration.

Moreover, `nixos-lima` integrates the lima-vm configuration into the NixOS module
system and provides a unified configuration experience.
