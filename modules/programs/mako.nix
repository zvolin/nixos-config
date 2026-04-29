{...}: {
  flake.modules.homeManager.mako = {
    pkgs,
    lib,
    config,
    ...
  }: {
    services.mako = {
      enable = true;
      settings = {
        default-timeout = 10000;
        border-size = 1;
        border-radius = 5;
        padding = "8,10";
        max-icon-size = 32;
        width = 400;
        margin = 12;
        format = "<b>%s</b>\\n<span size=\"2pt\"> </span>\\n%b";
        font = lib.mkForce "${config.stylix.fonts.monospace.name} ${toString config.stylix.fonts.sizes.popups}";
      };
    };

    # provides notify-send command
    home.packages = [pkgs.libnotify];
  };
}
