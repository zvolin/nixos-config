{inputs, ...}: {
  flake.modules.nixos.hyprland = {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    home-manager.sharedModules = [inputs.self.modules.homeManager.hyprland];
  };

  flake.modules.homeManager.hyprland = {
    pkgs,
    lib,
    config,
    osConfig,
    ...
  }: let
    opacity = {
      active = 0.9;
      inactive = 0.9;
    };
  in {
    home.packages = with pkgs; [
      obs-studio
      vlc
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

    # enable opacity for bars with stylix
    stylix.opacity.desktop = opacity.active;

    wayland.windowManager.hyprland = let
      mod = "SUPER";
      modshift = "${mod}SHIFT";
      xkb = osConfig.services.xserver.xkb;
      colors = config.lib.stylix.colors;
      terminal = lib.getExe config.terminal;
      brightnessctl = lib.getExe pkgs.brightnessctl;
      brightness-init = pkgs.writeShellScript "brightness-init" ''
        if [ "$(cat /sys/class/power_supply/macsmc-ac/online)" = "1" ]; then
          touchbar-kbd-sync set 30%
        else
          touchbar-kbd-sync set 10%
        fi
      '';
      cliphist = lib.getExe pkgs.cliphist;
      cliphist-paste = pkgs.writeShellScript "cliphist-paste" ''
        ${cliphist} list |
          ${wofi} --dmenu |
          ${cliphist} decode |
          ${wl-copy} && ${wtype} -s 10 -M ctrl -s 10 -M shift -s 10 -k V
      '';
      grim = lib.getExe pkgs.grim;
      slurp = lib.getExe pkgs.slurp;
      swappy = lib.getExe pkgs.swappy;
      swaybg = lib.getExe pkgs.swaybg;
      hyprlock = lib.getExe pkgs.hyprlock;
      wofi = lib.getExe pkgs.wofi;
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
      waybar = lib.getExe pkgs.waybar;
      wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      wtype = lib.getExe pkgs.wtype;
    in {
      enable = true;
      xwayland.enable = true;
      systemd.enable = false;

      settings = {
        monitor = ["eDP-1, preferred, auto, 1.6"];

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

        # disable opacity for common streaming services
        windowrule = let
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
            [
              # restore stock opacity if no service title matched
              "opacity ${toString active} override ${toString inactive} override, match:class ${classRegex}"
              # disable opacity if service opened
              "opacity 1.0 override, match:title ${titleRegex}, match:class ${classRegex}"
            ]
            # disable blur for kitty
            ++ ["no_blur on, match:class kitty"];

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
          enable_swallow = true;
          swallow_regex = "^(kitty)$";
        };

        input.touchpad.tap-to-click = false;
        gestures = {
          gesture = [
            "3, horizontal, workspace" # swipe left/right between workspaces
          ];
        };

        bind =
          [
            "${modshift}, Return, exec, uwsm app -- ${terminal}"
            "${modshift}, C,      killactive"
            "${mod},      P,      exec, uwsm app -- ${wofi} --show run"
            "${modshift}, L,      exec, uwsm app -- ${hyprlock}"
            # scratchpads
            "${mod},      X,      togglespecialworkspace, kitty"
            # cycle workspaces
            "${mod},      H,      workspace, -1"
            "${mod},      L,      workspace, +1"
            # cycle windows
            "${mod},      Tab,    cyclenext"
            "${mod},      Tab,    bringactivetotop"
            "${modshift}, Tab,    swapnext"
            # todo: monitors
            # clipboard
            "${mod},      V,      exec, uwsm app -- ${cliphist-paste}"
            "${modshift}, V,      exec, uwsm app -- ${cliphist} wipe"
            # media
            '', XF86SelectiveScreenshot, exec, uwsm app -- ${grim} -g "$(${slurp})" - | ${swappy} -f -''
          ]
          ++ (
            # workspaces 1..10
            builtins.concatLists (
              builtins.genList (
                x: let
                  key' =
                    if x == 9
                    then 0
                    else x + 1;
                  key = toString key';
                  ws = toString (x + 1);
                in [
                  "${mod},      ${key}, workspace, ${ws}"
                  "${modshift}, ${key}, movetoworkspace, ${ws}"
                ]
              )
              10
            )
          );

        # binds working when lock active
        bindl = [
          ", XF86AudioMute,    exec, uwsm app -- ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioMicMute, exec, uwsm app -- ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          # power button wakes screen (logind ignores short press, long press still shuts down)
          # ", XF86PowerOff,     exec, hyprctl dispatch dpms on"
        ];

        # binds repeated when held, working when lock active
        bindel = [
          ", XF86AudioRaiseVolume,  exec, uwsm app -- ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%+"
          ", XF86AudioLowerVolume,  exec, uwsm app -- ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%-"
          # Keyboard brightness keys sync touchbar and kbd_backlight
          ", XF86KbdBrightnessDown, exec, uwsm app -- touchbar-kbd-sync down"
          ", XF86KbdBrightnessUp,   exec, uwsm app -- touchbar-kbd-sync up"
          # Display brightness keys control display only
          ", XF86MonBrightnessDown, exec, uwsm app -- ${brightnessctl} set 1%-"
          ", XF86MonBrightnessUp,   exec, uwsm app -- ${brightnessctl} set 1%+"
        ];

        bezier = [
          "custom, 0.36, 0.6, 0.94, 0.37"
          "ease_in_expo, 0.7, 0, 0.84, 0"
          "ease_out_expo, 0.16, 1, 0.3, 1"
        ];

        animation = [
          "specialWorkspace, 1, 5, custom, slidefadevert -50%"
        ];

        exec-once = [
          # DPMS cycle to reinitialize DCP backlight (workaround for "Could not find Backlight service")
          "hyprctl dispatch dpms off && hyprctl dispatch dpms on"
          # Set startup brightness based on AC/battery status
          "${brightness-init}"
          "${waybar}"
          "${swaybg} -o '*' -m fill -i ${config.stylix.image}"
          "[workspace special:kitty silent; float; move 25% 10%; size 70% 70%] ${terminal}"
        ];
      };
    };
  };
}
