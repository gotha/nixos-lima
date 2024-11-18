# NixOS for MacOS using Lima-VM

## Usage (off-the-shelf)

```
nix run github:ciderale/nixos-lima start
```

The above command boots a VM using lima and deploys an NixOS configuration.
The configuration includes docker engine and adds some default volume mounts.

In addition to lima-vm.io's port forwarding, nixos-lima can listens to the
docker event stream and thus provide port mapping more promptly than via polling.

```
nix run github:ciderale/nixos-lima portmapperd
```

The subcommand `nix run github:ciderale/nixos-lima full` combines `start`
and `portmapperd` in one. Stopping `full` with ctrl-c currently also stops
the virtual machine.

## Adhoc customization using NIXOS_LIMA_IMPURE_CONFIG

```
NIXOS_LIMA_IMPURE_CONFIG=addition1.nix,addition2.nix nix run github:ciderale/nixos-lima start
```

Additional configurations can be provided via the NIXOS_LIMA_IMPURE_CONFIG environment variable.
The referenced configuration files are merged into the existing configuration using
the nix modules `{ imports = [ ... ]; }` expression. Multiple files may be referenced
(separated by comma) by absolute path or relative to the current working directory.

The configuration includes all NixOS configurations as well as the lima-vm configurations.
The options under `lima.settings` are used to generate the lima.yaml configuration template.
This controls volume mounts, but also cpu and memory sizing. See "example/lima-settings.nix"
for some examples. Changes to lima.settings result in a restart of the lima-vm.

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
