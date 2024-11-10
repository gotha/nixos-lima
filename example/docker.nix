{config, ...}: {
  virtualisation.docker.enable = true;
  lima.settings.portForwards = [
    {
      guestSocket = "/run/docker.sock"; # user must be in group docker
      hostSocket = "{{.Dir}}/sock/docker.sock";
    }
  ];
  users.users.${config.lima.user.name}.extraGroups = ["docker"];
}
