{ ... }:
{
  flake.modules.homeManager.connman-gui =
    { pkgs, ... }:
    {
      # CMST - Qt GUI for ConnMan
      home.packages = [ pkgs.cmst ];

      # Launch CMST when clicking network in waybar
      programs.waybar.settings = [
        {
          network.on-click = "cmst";
        }
      ];

      wayland.windowManager.hyprland.settings.window_rule = [
        {
          name = "connman-gui-cmst-float";
          match.class = "cmst";
          float = true;
          center = true;
        }
      ];
    };
}
