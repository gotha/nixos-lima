{ lib, pkgs, ... }: {
  system.stateVersion = "25.05";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = map lib.lowPrio [ pkgs.vim pkgs.curl pkgs.git ];

  lima.settings = {
    cpus = 8;
    memory = "16GB";
    disk = "240GB";
    mounts = [{
      location = "/Users/gotha/Projects";
      mountPoint = "/home/gotha/Projects";
      writable = true;
    }];
  };

}
