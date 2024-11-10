{
  lima.user.name = "ale";
  lima.user.sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKyKsE4eCn8BDnJZNmFttaCBmVUhO73qmhguEtNft6y";
  lima.settings.ssh.localPort = 2222;
  lima.settings.mounts = [
    {location = "/Users/ale";}
    {
      location = "/tmp/lima";
      writable = true;
    }
  ];
}
