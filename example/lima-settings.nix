{
  lima.settings.ssh.localPort = 2222;
  lima.settings.mounts = [
    {location = "/Users/ale";}
    {
      location = "/tmp/lima";
      writable = true;
    }
  ];
  lima.settings.memory = "8GB";
  lima.settings.cpus = 8;
}
