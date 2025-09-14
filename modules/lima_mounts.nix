{ config, lib, ... }:
let
  cfg = config.lima;
  fsMounts = lib.lists.imap0 (i:
    { location, writable ? false, mountPoint, }: {
      name = if mountPoint == null then location else mountPoint;
      value.device = "mount${toString i}";
      value.fsType = "virtiofs";
      value.options = [ "nofail" ]; # nofail: don't hang when mount is removed
    }) cfg.settings.mounts;
in {
  ## filesystem mounts provided by user
  fileSystems = lib.listToAttrs fsMounts;
}
