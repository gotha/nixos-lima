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
  docker-client,
  coreutils,
  fetchurl,
}: rec {
  inherit lima-bin docker-client;
  lima = lima-bin.overrideAttrs (old: rec {
    version = "1.0.1";
    src = fetchurl {
      url = "https://github.com/lima-vm/lima/releases/download/v${version}/lima-${version}-Darwin-arm64.tar.gz";
      sha256 = "sha256-ZOczmgKT9lhj28iKBSMp4LBmb/+8CByOAs+QEjoaogw=";
    };
    doInstallCheck = false;
  });
  nixos-anywhere-mod = nixos-anywhere.overrideAttrs (old: {
    installPhase = ''
      # patch-in support for 'nix --impure'
      sed -i -e 's/case "$1" in/case "$1" in\n    --impure)\n      nixOptions+=(--impure)\n      ;;\n/' src/nixos-anywhere.sh
      ${old.installPhase}
    '';
  });
  portmapperd = writeShellApplication {
    name = "portmapperd.sh";
    runtimeInputs = [docker-client openssh coreutils];
    text = builtins.readFile ./portmapperd.sh;
  };
  nixos-lima = writeShellApplication {
    name = "nixos-lima";
    runtimeInputs = [lima nixos-anywhere-mod nixos-rebuild diffutils jq nix gnused portmapperd];
    text = ''
      NIXOS_LIMA_CONFIG=~/.lima/_config
      NIXOS_LIMA_SSH_KEY=$NIXOS_LIMA_CONFIG/user
      NIXOS_LIMA_IDENTITY_OPTS=(-i "$NIXOS_LIMA_SSH_KEY")
      NIXOS_LIMA_SSH_PUB_KEY=$NIXOS_LIMA_CONFIG/user.pub

      FLAKE_NAME=''${1:-}
      CMD=''${2:-}
      shift 2 || (
        sed -E -n -e 's/^[[:space:]]+([^[:space:]]+)\)/usage: nixos-lima <VM_NAME> \1/p' "$0"
        echo "   VM_NAME is a flake attribute for a nixosConfiguration.VM_NAME"
        echo "           defaults to flake in current working dir if no no flake path given"
        exit 1
      )

      # extract FLAKE and NAME (and default to flake in current folder)
      if [[ ! "$FLAKE_NAME" =~ "#" ]]; then FLAKE_NAME=".#$FLAKE_NAME"; fi
      NAME=''${FLAKE_NAME#*#}
      FLAKE=''${FLAKE_NAME%#*}

      # autodetect the current user
      # set nixos configuration via impure environment variables
      NIXOS_LIMA_IMPURE=--impure
      # keep it out of the vm folder name to avoid creation issues
      VM_IMPURE_CFG="$HOME/.lima/$NAME.vm-impure-config.nix"
      cat > "$VM_IMPURE_CFG" <<-EOF
      {
        lima = {
          vmName="$NAME";
          user.name = "$(id -nu)";
          user.sshPubKey = "$(cat "$NIXOS_LIMA_SSH_PUB_KEY")";
        };
      }
      EOF
      export NIXOS_LIMA_IMPURE_CONFIG="$VM_IMPURE_CFG,''${NIXOS_LIMA_IMPURE_CONFIG:-}"

      function fail() {
        echo "$@"; exit 1
      }
      function load_configuration() {
          CONFIG="$FLAKE#nixosConfigurations.$NAME.config"
          CONFIG_JSON="$(nix eval --json "$CONFIG.lima" $NIXOS_LIMA_IMPURE)"
          USER_NAME="$(echo "$CONFIG_JSON" | jq -e -r .user.name)" || fail "no lima.user.name"
          SSH_PORT="$(echo "$CONFIG_JSON" | jq -e -r .settings.ssh.localPort)" || fail "no lima.settings.ssh.localPort"
          THE_TARGET="$USER_NAME@localhost"
      }

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
          ${openssh}/bin/ssh -p "$SSH_PORT" "$THE_TARGET" "''${NIXOS_LIMA_IDENTITY_OPTS[@]}"
          ;;

        portmapperd)
          echo "# NIXOS-LIMA: starting portmapperd for VM $NAME"
          LIMA_FOLDER="$(limactl list "$NAME" --json | jq -r '.dir')"
          export CONTAINER_HOST="unix://$LIMA_FOLDER/sock/docker.sock"
          export DOCKER_HOST="$CONTAINER_HOST"

          # PORTMAPPER_LOG="$LIMA_FOLDER/portmapperd.log"
          VERBOSE=2 portmapperd.sh -S "$LIMA_FOLDER/ssh.sock" "lima-$NAME"
          # stopping a backgrounded version is tricky..
          ;;

        full)
          $0 "$FLAKE_NAME" start
          $0 "$FLAKE_NAME" portmapperd
          ;;

        start)
          echo ""
          echo "#####################################"
          echo "# Welcome to the nixos-lima utility #"
          echo "#####################################"

          echo "# NIXOS-LIMA: starting VM $NAME -- creating and updating if necessary"
          echo "# NIXOS-LIMA: extract configuration parameters from nix module"
          load_configuration

          echo "# NIXOS-LIMA: ensure vm exists"
          LIMA_CONFIG_YAML="$(nix build --no-link --print-out-paths "$CONFIG.lima.configFile" $NIXOS_LIMA_IMPURE)"
          if ! limactl list "$NAME" | grep "$NAME"; then
            echo "# NIXOS-LIMA: create vm with lima"
            limactl create --name="$NAME" "$LIMA_CONFIG_YAML"
            ssh-keygen -R "[localhost]:$SSH_PORT"
            limactl start "$NAME"

            echo "# NIXOS-LIMA: install nixos with nixos-anywhere"
            nixos-anywhere \
              $NIXOS_LIMA_IMPURE \
              -i $NIXOS_LIMA_SSH_KEY \
              --build-on-remote "$THE_TARGET" -p "$SSH_PORT" \
              --post-kexec-ssh-port "$SSH_PORT" \
              --flake "$FLAKE_NAME"
            SKIP_NIXOS_REBUILD=yes

            echo "# NIXOS-LIMA: ssh-keyscan to check if vm is up-and-running"
            while ! ssh-keyscan -4 -p "$SSH_PORT" localhost; do sleep 2; done
          fi
          echo "# NIXOS-LIMA: vm configuration exists"

          echo "# NIXOS-LIMA: ensure vm configuration lima.yaml is up-to-date"
          LIMA_YAML="$(limactl list "$NAME" --json | jq -r '.dir')/lima.yaml"
          if ! diff -C 5 "$LIMA_YAML" <(jq . "$LIMA_CONFIG_YAML"); then
            limactl stop -f "$NAME"
            jq . "$LIMA_CONFIG_YAML" > "$LIMA_YAML"
          fi
          echo "# NIXOS-LIMA: lima.yaml is up-to-date"

          echo "# NIXOS-LIMA: ensure vm is up-and-running"
          if ! limactl list "$NAME" | grep Running; then
            limactl start "$NAME"
          fi
          echo "# NIXOS-LIMA: vm is running"

          if [ "''${SKIP_NIXOS_REBUILD:-}" != "yes" ]; then
            echo "# NIXOS-LIMA: Deploying $FLAKE_NAME to $THE_TARGET"
            export NIX_SSHOPTS="-o ControlPath=/tmp/ssh-nixos-vm-%n -o Port=$SSH_PORT ''${NIXOS_LIMA_IDENTITY_OPTS[*]}"
            nixos-rebuild \
              $NIXOS_LIMA_IMPURE \
              --flake "$FLAKE_NAME" \
              --fast --target-host "$THE_TARGET" --build-host "$THE_TARGET" \
              --use-remote-sudo \
              switch "$@"
          fi
          echo "# NIXOS-LIMA: vm is up-to-date and running"
          ;;
        *)
          echo "# NIXOS-LIMA: unknown command $CMD"
          ;;
      esac
    '';
  };
}
