# this module allows for providing addiitonal configuration
# via pointing NIXOS_LIMA_IMPURE_CONFIG to a nix configuration file
# e.g. NIXOS_LIMA_IMPURE_CONFIG=$PWD/additional.nix nixos-lima mynixos start
# the module environment variable may list multiple files (csv-like)
{lib, ...}: let
  cfgFilesCsv = builtins.getEnv "NIXOS_LIMA_IMPURE_CONFIG";
  pwd = builtins.getEnv "PWD";

  csvToList = s:
    lib.filter (f: lib.isString f && f != "")
    (lib.split "," s);
  makeAbsolute = p:
    if (lib.substring 0 1 p) == "/"
    then p
    else "${pwd}/${p}";
in {
  imports = map makeAbsolute (csvToList cfgFilesCsv);
}
