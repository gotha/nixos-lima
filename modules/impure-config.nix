# this module allows for providing addiitonal configuration
# via pointing NIXOS_LIMA_IMPURE_CONFIG to a nix configuration file
# e.g. NIXOS_LIMA_IMPURE_CONFIG=$PWD/additional.nix nixos-lima mynixos start
let
  cfgFile = builtins.getEnv "NIXOS_LIMA_IMPURE_CONFIG";
  pwd = builtins.getEnv "PWD";
  makeAbsolute = p:
    if (builtins.substring 0 1 p) == "/"
    then p
    else "${pwd}/${p}";
in {
  imports =
    if (cfgFile != "")
    then [(makeAbsolute cfgFile)]
    else [];
}
