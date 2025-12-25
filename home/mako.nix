{ pkgs, ... }:

{
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 8;
    };
  };

  # provides notify-send command
  home.packages = [ pkgs.libnotify ];
}
