{
  config,
  lib,
  ...
}: {
  #lima.settings.plain = true; #disables mounts,ports,ga,etc
  lima.settings.ssh.localPort = 2222;
  lima.settings.mounts = [
    {location = "/Users/${config.lima.user.name}";}
    {
      location = "/tmp/lima";
      writable = true;
    }
  ];
  #lima.settings.video.display = "vz"; add gui
  lima.settings.memory = lib.mkDefault "8GB";
  lima.settings.cpus = lib.mkDefault 8;
  lima.settings.disk = lib.mkDefault "60GB";
  virtualisation.containers.registries.search = [
    "docker.io"
    "quay.io"
  ];
}
