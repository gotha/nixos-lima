{
  # requires nix "--impure" which is currently applied in nixos-lima
  lima.user.name = builtins.getEnv "NIXOS_LIMA_USER_NAME";
  lima.user.sshPubKey = builtins.getEnv "NIXOS_LIMA_SSH_PUB_KEY";
}
