{ lib, pkgs, config, ... }:

{
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    wofi
    wtype
    xdg-utils
  ];

  home.sessionVariables = {
    # for correct wayland support
    QT_QPA_PLATFORM = "wayland";
    MOZ_ENABLE_WAYLAND = 1;
    GDK_BACKEND = "wayland";
  };

  # todo: https://github.com/nix-community/home-manager/pull/5346
  # services.cliphist.enable = true;

  # portal - used for programs requesting things from wm, like file picker, screen sharing etc.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    config = {
      common.default = [
        "gtk" # file picker
        "hyprland" # everything
      ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  wayland.windowManager.hyprland = let
    mod = "SUPER";
    modshift = "${mod}SHIFT";
    terminal = "kitty";
    xkb = (import ../nix/i18n.nix {}).config.services.xserver.xkb;
  in {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;

    settings = {
      monitor = [
        "eDP-1, preferred, auto, 1.6"
      ];

      input = {
        kb_layout = xkb.layout;
	      kb_variant = xkb.variant;
      };

      general = {
        gaps_in = 6;
	      gaps_out = 11;
	      border_size = 1;
	      "col.active_border" = "rgba(3472ddee) rgba(fef5fe80) 45deg";
      };

      decoration = {
        rounding = 5;
      };

      misc = {
      };

      input.touchpad.tap-to-click = false;

      bind = [
        "${modshift}, Return, exec, ${terminal}"
        "${modshift}, C,      killactive"
	      "${mod},      P,      exec, wofi --show run"
        # cycle workspaces
	      "${mod},      H,      workspace, -1"
	      "${mod},      L,      workspace, +1"
	      # cycle windows
	      "${mod},      Tab,    cyclenext"
	      "${mod},      Tab,    bringactivetotop"
	      "${modshift}, Tab,    swapnext"
	      # todo: monitors
        # clipboard
        "${mod},      V,      exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy && wtype -s 10 -M ctrl -s 10 -M shift -s 10 -k V"
        "${modshift}, V,      exec, cliphist wipe"
      ] ++ (
        # workspaces 1..10
	      builtins.concatLists (builtins.genList (
	          x: let
	            key' = if x == 9 then 0 else x + 1;
	            key = builtins.toString key';
	            ws = builtins.toString (x + 1);
	          in [
	            "${mod},      ${key}, workspace, ${ws}"
	            "${modshift}, ${key}, movetoworkspace, ${ws}"
	          ]
	        )
	        10
	      )
      );

      env = [
      ];

      exec-once = [
        "waybar"
        # todo: https://github.com/nix-community/home-manager/pull/5346
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];
    };
  };
}
