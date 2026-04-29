{...}: {
  flake.modules.homeManager.connman-gui = {pkgs, ...}: {
    # CMST - Qt GUI for ConnMan
    home.packages = [pkgs.cmst];

    # Launch CMST when clicking network in waybar
    programs.waybar.settings = [
      {
        network.on-click = "cmst";
      }
    ];

    # Float and center CMST window
    wayland.windowManager.hyprland.settings.windowrule = [
      "float on, match:class cmst"
      "center on, match:class cmst"
    ];
  };
}
