{
  writeShellApplication,
  nixos-rebuild,
  lima-bin,
  nixos-anywhere,
}: {
  inherit lima-bin;
  nixosDeploy = writeShellApplication {
    name = "nixosDeploy";
    runtimeInputs = [nixos-rebuild];
    text = ''
      set -x
      NAME=$1
      shift


      FLAKE=".#$NAME"
      CONFIG=".#nixosConfigurations.$NAME.config"

      THE_TARGET="root@localhost"
      SSH_PORT="$(nix eval "$CONFIG.lima.ssh.localPort")" # or us jq?

      echo "Deploying $FLAKE to $THE_TARGET"
      export NIX_SSHOPTS="-o ControlPath=/tmp/ssh-utm-vm-%n -o Port=$SSH_PORT"
      nixos-rebuild \
        --flake "$FLAKE" \
        --fast --target-host "$THE_TARGET" --build-host "$THE_TARGET" \
        switch "$@"
    '';
  };

  nixos-lima = writeShellApplication {
    name = "nixos-lima";
    runtimeInputs = [lima-bin nixos-anywhere];
    text = ''
      echo "Welcome to the nixos-lima utility"
      set -x
      NAME=$1
      shift

      FLAKE=".#$NAME"
      CONFIG=".#nixosConfigurations.$NAME.config"

      case "''${1:-}" in
        delete)
          limactl stop example
          limactl remove example
          ;;

        *)
          SSH_PORT="$(nix eval "$CONFIG.lima.ssh.localPort")" # or us jq?
          LIMA_YAML="$(nix build --no-link --print-out-paths "$CONFIG.lima.yaml")"
          THE_TARGET="root@localhost" ## user depends on nixos configuration

          if ! limactl list "$NAME"; then
            limactl create --name="$NAME" "$LIMA_YAML"
            ssh-keygen -R "[localhost]:$SSH_PORT"
            limactl start "$NAME"

            nixos-anywhere --flake "$FLAKE" --build-on-remote ale@localhost -p "$SSH_PORT" --post-kexec-ssh-port "$SSH_PORT"

            echo "# wait till ssh server is up-and-running: ssh-keyscan gets a key"
            while ! ssh-keyscan -4 -p "$SSH_PORT" localhost; do sleep 2; done
          fi
          if ! limactl list "$NAME" | grep Running; then
            limactl start "$NAME"
          fi

          ssh -p "$SSH_PORT" "$THE_TARGET"
          ;;
      esac
    '';
  };
}
