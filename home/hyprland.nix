{
  pkgs,
  lib,
  config,
  ...
}:

let
  opacity = {
    active = 0.9;
    inactive = 0.9;
  };
in
{
  home.packages = with pkgs; [
    brightnessctl
    cliphist
    grim
    slurp
    swappy
    swaybg
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

  # enable clipboard history service
  services.cliphist.enable = true;

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

  # enable opacity for bars with stylix
  stylix.opacity.desktop = opacity.active;

  wayland.windowManager.hyprland =
    let
      mod = "SUPER";
      modshift = "${mod}SHIFT";
      terminal = "kitty";
      xkb = (import ../nix/i18n.nix { }).config.services.xserver.xkb;
      colors = config.lib.stylix.colors;
    in
    {
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;

      settings = {
        monitor = [ "eDP-1, preferred, auto, 1.6" ];

        input = {
          kb_layout = xkb.layout;
          kb_variant = xkb.variant;
        };

        general = {
          gaps_in = 6;
          gaps_out = 11;
          border_size = 1;
          "col.active_border" = lib.mkForce (
            lib.concatStringsSep " " [
              "rgba(${colors.base0D}fa)"
              "rgba(${colors.base0D}85)"
              "rgba(${colors.base0C}55)"
              "60deg"
            ]
          );
        };

        decoration = {
          rounding = 5;
          active_opacity = opacity.active;
          inactive_opacity = opacity.inactive;
          blur = {
            enabled = true;
            size = 5;
            passes = 1;
            popups = true;
          };
        };

        # disable blur for kitty
        windowrule = [ "noblur,^(kitty)$" ];

        # disable opacity for common streaming services
        windowrulev2 =
          let
            services = [
              "YouTube"
              "HBO"
              "Prime Video"
              "Netflix"
              "Disney"
              "CDA"
              "Player.pl"
            ];
            titleRegex = lib.concatMapStringsSep "|" (name: "(.*${name}.*)") services;
            browsers = [
              "firefox"
              "Chromium-browser"
            ];
            classRegex = lib.concatStringsSep "|" browsers;
          in
          with opacity;
          with builtins;
          [
            # restore stock opacity if no service title matched
            "opacity ${toString active} override ${toString inactive} override, class:(${classRegex})"
            # disable opacity if service opened
            "opacity 1.0 override, title:(${titleRegex}), class:(${classRegex})"
          ];

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
        };

        input.touchpad.tap-to-click = false;

        bind =
          [
            ''${modshift}, Return, exec, ${terminal}''
            ''${modshift}, C,      killactive''
            ''${mod},      P,      exec, wofi --show run''
            ''${modshift}, L,      exec, swaylock''
            # scratchpads
            ''${mod},      X,      togglespecialworkspace, kitty''
            # cycle workspaces
            ''${mod},      H,      workspace, -1''
            ''${mod},      L,      workspace, +1''
            # cycle windows
            ''${mod},      Tab,    cyclenext''
            ''${mod},      Tab,    bringactivetotop''
            ''${modshift}, Tab,    swapnext''
            # todo: monitors
            # clipboard
            ''${mod},      V,      exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy && wtype -s 10 -M ctrl -s 10 -M shift -s 10 -k V''
            ''${modshift}, V,      exec, cliphist wipe''
            # media
            '', XF86SelectiveScreenshot, exec, grim -g "$(slurp)" - | swappy -f -''
          ]
          ++ (
            # workspaces 1..10
            builtins.concatLists (
              builtins.genList (
                x:
                let
                  key' = if x == 9 then 0 else x + 1;
                  key = builtins.toString key';
                  ws = builtins.toString (x + 1);
                in
                [
                  "${mod},      ${key}, workspace, ${ws}"
                  "${modshift}, ${key}, movetoworkspace, ${ws}"
                ]
              ) 10
            )
          );

        # binds working when lock active
        bindl = [
          '', XF86AudioMute,    exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle''
          '', XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle''
        ];

        # binds repeated when held, working when lock active
        bindel = [
          '', XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+''
          '', XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-''
          '', XF86KbdBrightnessDown, exec, brightnessctl set 1%- -d kbd_backlight''
          '', XF86KbdBrightnessUp,   exec, brightnessctl set 1%+ -d kbd_backlight''
          '', XF86MonBrightnessDown, exec, brightnessctl set 1%-''
          '', XF86MonBrightnessUp,   exec, brightnessctl set 1%+''
        ];

        env = [ ];

        bezier = [
          "custom, 0.36, 0.6, 0.94, 0.37"
          "ease_in_expo, 0.7, 0, 0.84, 0"
          "ease_out_expo, 0.16, 1, 0.3, 1"
        ];

        animation = [
          # "windows, 1, 15, custom, popin"
          "specialWorkspace, 1, 5, custom, slidefadevert -50%"
        ];

        exec-once = [
          "waybar"
          "swaybg -o '*' -m fill -i ${config.stylix.image}"
          "[workspace special:kitty silent; float; move 15% 10%; size 70% 70%] kitty"
        ];
      };
    };
}
