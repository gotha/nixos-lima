# NixOS for MacOS using Lima-VM

## Usage (off-the-shelf)

```
nix run github:ciderale/nixos-lima start
```

The above command boots a VM using lima and deploys an NixOS configuration.
The configuration includes docker engine and adds some default volume mounts.

## Container support

The default nixos-lima configuration includes a docker installation.
The shell rc script `~/.lima/mynixos.shrc` will setup the DOCKER_HOST
and CONTAINER_HOST variable and add `docker` to your PATH variable.
You could add this to your .zprofile startup script for example.

In addition to lima-vm.io's port forwarding, nixos-lima can listens to the
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
Nixos-lima takes care of the entire process.

Technically, the referenced configuration files are merged into the existing
configuration using the nix modules `{ imports = [ ... ]; }` expression.
Multiple files may be referenced (separated by comma) by absolute path or
relative to the current working directory.


## Usage with advanced customisation

More advanced configuration are better versioned explicitly using git. The
nixos-lima repository provides a nix flake template to start building the own
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
