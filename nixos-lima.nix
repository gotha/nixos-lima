{
  writeShellApplication,
  nixos-rebuild,
  lima-bin,
  nixos-anywhere,
  diffutils,
  openssh,
  jq,
  nix,
  gnused,
}: {
  inherit lima-bin;
  nixos-lima = writeShellApplication {
    name = "nixos-lima";
    runtimeInputs = [lima-bin nixos-anywhere nixos-rebuild diffutils jq nix gnused];
    text = ''
      function load_configuration() {
          CONFIG=".#nixosConfigurations.$NAME.config"
          CONFIG_JSON="$(nix eval --json "$CONFIG.lima")"
          USER_NAME="$(echo "$CONFIG_JSON" | jq -r .user.name)"
          SSH_PORT="$(echo "$CONFIG_JSON" | jq -r .ssh.localPort)"
          THE_TARGET="$USER_NAME@localhost"
      }

      NAME=''${1:-}
      CMD=''${2:-}
      shift 2 || (
        sed -E -n -e 's/^[[:space:]]+([^[:space:]]+)\)/usage: nixos-lima <VM_NAME> \1/p' "$0"
        exit 1
      )

      case "$CMD" in
        reboot)
          limactl stop -f "$NAME" && limactl start "$NAME"
          ;;

        delete)
          limactl stop -f "$NAME"
          limactl remove "$NAME"
          ;;

        stop|shell|list|ls)
          limactl "$CMD" "$NAME" "''${@}"
          ;;

        ssh)
          load_configuration
          ${openssh}/bin/ssh -p "$SSH_PORT" "$THE_TARGET"
          ;;

        start)
          echo ""
          echo "#####################################"
          echo "# Welcome to the nixos-lima utility #"
          echo "#####################################"

          FLAKE=".#$NAME"
          echo "# NIXOS-LIMA: starting VM $FLAKE -- creating and updating if necessary"

          echo "# NIXOS-LIMA: extract configuration parameters from nix module"
          load_configuration

          echo "# NIXOS-LIMA: ensure vm exists"
          LIMA_CONFIG_YAML="$(nix build --no-link --print-out-paths "$CONFIG.lima.yaml")"
          if ! limactl list "$NAME" | grep "$NAME"; then
            echo "# NIXOS-LIMA: create vm with lima"
            limactl create --name="$NAME" "$LIMA_CONFIG_YAML"
            ssh-keygen -R "[localhost]:$SSH_PORT"
            limactl start "$NAME"

            echo "# NIXOS-LIMA: install nixos with nixos-anywhere"
            nixos-anywhere --flake "$FLAKE" --build-on-remote "$THE_TARGET" -p "$SSH_PORT" --post-kexec-ssh-port "$SSH_PORT"

            echo "# NIXOS-LIMA: ssh-keyscan to check if vm is up-and-running"
            while ! ssh-keyscan -4 -p "$SSH_PORT" localhost; do sleep 2; done
          fi
          echo "# NIXOS-LIMA: vm configuration exists"

          echo "# NIXOS-LIMA: ensure vm configuration lima.yaml is up-to-date"
          LIMA_YAML="$(limactl list "$NAME" --json | jq -r '.dir')/lima.yaml"
          if ! diff "$LIMA_YAML" "$LIMA_CONFIG_YAML"; then
            limactl stop -f "$NAME"
            cp "$LIMA_CONFIG_YAML" "$LIMA_YAML"
          fi
          echo "# NIXOS-LIMA: lima.yaml is up-to-date"

          echo "# NIXOS-LIMA: ensure vm is up-and-running"
          if ! limactl list "$NAME" | grep Running; then
            limactl start "$NAME"
          fi
          echo "NIXOS-LIMA: vm is running"

          echo "# NIXOS-LIMA: Deploying $FLAKE to $THE_TARGET"
          export NIX_SSHOPTS="-o ControlPath=/tmp/ssh-nixos-vm-%n -o Port=$SSH_PORT"
          nixos-rebuild \
            --flake "$FLAKE" \
            --fast --target-host "$THE_TARGET" --build-host "$THE_TARGET" \
            --use-remote-sudo \
            switch "$@"
          echo "NIXOS-LIMA: vm is up-to-date and running"
          ;;
      esac
    '';
  };
}
