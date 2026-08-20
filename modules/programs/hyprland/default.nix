{ inputs, ... }:
{
  flake.modules.nixos.hyprland = {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    home-manager.sharedModules = [ inputs.self.modules.homeManager.hyprland ];
  };

  flake.modules.homeManager.hyprland =
    {
      pkgs,
      lib,
      config,
      osConfig,
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
        obs-studio
        vlc
        brightnessctl
        cliphist
        grim
        slurp
        satty
        swaybg
        wl-clipboard
        wofi
        wtype
        xdg-utils
      ];

      # HM's Hyprland module enables xdg.portal with only hyprland-portal and
      # points NIX_XDG_DESKTOP_PORTAL_DIR at the user profile, hiding gtk.portal
      # from the system. Without gtk the Settings interface is unreachable, so
      # Flutter/GTK apps fall back to light theme (white-on-white text).
      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      xdg.portal.config = {
        common.default = [ "gtk" ];
        hyprland.default = [
          "hyprland"
          "gtk"
        ];
      };

      home.sessionVariables = {
        # for correct wayland support
        QT_QPA_PLATFORM = "wayland";
        MOZ_ENABLE_WAYLAND = 1;
        GDK_BACKEND = "wayland";
      };

      services.cliphist.enable = true;

      # enable opacity for bars with stylix
      stylix.opacity.desktop = opacity.active;

      wayland.windowManager.hyprland =
        let
          inherit (lib.generators) mkLuaInline;
          toLua = lib.generators.toLua { };
          # `_args` renders the attrset as positional arguments
          # (`hl.curve(name, opts)`) rather than as a single table argument.
          mkBezier = name: points: {
            _args = [
              name
              {
                type = "bezier";
                inherit points;
              }
            ];
          };
          xkb = osConfig.services.xserver.xkb;
          colors = config.lib.stylix.colors;
          terminal = lib.getExe config.terminal;
          brightness-init = pkgs.writeShellScript "brightness-init" ''
            if [ "$(cat /sys/class/power_supply/macsmc-ac/online)" = "1" ]; then
              touchbar-kbd-sync set 30%
            else
              touchbar-kbd-sync set 10%
            fi
          '';
          swaybg = lib.getExe pkgs.swaybg;
          waybar = lib.getExe pkgs.waybar;
        in
        {
          enable = true;
          # Home Manager's default is state-version driven (lua at 26.05+), and
          # home.stateVersion is 24.05, so this has to be explicit.
          configType = "lua";
          xwayland.enable = true;
          systemd.enable = false;

          settings = {
            monitor = {
              output = "eDP-1";
              mode = "preferred";
              position = "auto";
              # A string, not a number: MONITOR_FIELDS declares scale as a
              # config string, same as mode and position.
              scale = "1.6";
            };

            # swipe left/right between workspaces
            gesture = {
              fingers = 3;
              direction = "horizontal";
              action = "workspace";
            };

            config = {
              input = {
                kb_layout = xkb.layout;
                kb_variant = xkb.variant;
                touchpad.tap_to_click = false;
              };

              general = {
                gaps_in = 6;
                gaps_out = 11;
                border_size = 1;
                # Must stay on stylix's exact attribute path. Writing this as the
                # nested config.general.col.active_border is a different Nix path,
                # so mkForce would have nothing to override and both keys would
                # land side by side in the emitted table.
                "col.active_border" = lib.mkForce {
                  colors = [
                    "rgba(${colors.base0D}fa)"
                    "rgba(${colors.base0D}85)"
                    "rgba(${colors.base0C}55)"
                  ];
                  angle = 60;
                };
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

              misc = {
                disable_hyprland_logo = true;
                disable_splash_rendering = true;
                force_default_wallpaper = 0;
                enable_swallow = true;
                swallow_regex = "^(kitty)$";
              };
            };

            # Order matters: rules register in list order, and the streaming rule
            # only wins over the browser rule because it registers second. Sorting
            # this list would silently drop streaming opacity.
            #
            # Rules are also keyed by `name`; a duplicate name replaces the
            # earlier rule instead of adding one. audio.nix and connman-gui.nix
            # merge into this same list, so names are module-prefixed to keep
            # them distinct.
            window_rule =
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
              [
                # restore stock opacity if no service title matched
                {
                  name = "hyprland-browser-opacity";
                  match.class = classRegex;
                  opacity = "${toString opacity.active} override ${toString opacity.inactive} override";
                }
                # disable opacity for common streaming services
                {
                  name = "hyprland-streaming-opacity";
                  match = {
                    class = classRegex;
                    title = titleRegex;
                  };
                  opacity = "1.0 override";
                }
                {
                  name = "hyprland-kitty-no-blur";
                  match.class = "kitty";
                  no_blur = true;
                }
              ];

            curve = [
              (mkBezier "custom" [
                [
                  0.36
                  0.6
                ]
                [
                  0.94
                  0.37
                ]
              ])
              (mkBezier "ease_in_expo" [
                [
                  0.7
                  0
                ]
                [
                  0.84
                  0
                ]
              ])
              (mkBezier "ease_out_expo" [
                [
                  0.16
                  1
                ]
                [
                  0.3
                  1
                ]
              ])
            ];

            # `animation` sorts before `curve`, but `curve` is in home-manager's
            # default importantPrefixes and renders first, so the "custom" curve
            # already exists by the time this runs.
            animation = {
              leaf = "specialWorkspace";
              enabled = true;
              speed = 5;
              bezier = "custom";
              style = "slidefadevert -50%";
            };

            # Autostart. hl.exec_cmd is the direct call; hl.dsp.exec_cmd (used
            # in the binds) builds a dispatcher.
            on = {
              _args = [
                "hyprland.start"
                (mkLuaInline ''
                  function()
                    -- DPMS cycle to reinitialize DCP backlight (workaround for "Could not find Backlight service")
                    -- Dispatched in-process; shelling out to hyprctl would have to
                    -- round-trip through the lua evaluator for no gain.
                    hl.dispatch(hl.dsp.dpms({ action = "off" }))
                    hl.dispatch(hl.dsp.dpms({ action = "on" }))
                    -- Set startup brightness based on AC/battery status
                    hl.exec_cmd(${toLua brightness-init})
                    hl.exec_cmd(${toLua waybar})
                    hl.exec_cmd(${toLua "${swaybg} -o '*' -m fill -i ${config.stylix.image}"})
                    hl.exec_cmd(${toLua terminal}, {
                      workspace = "special:kitty silent",
                      float     = true,
                      move      = "25% 10%",
                      size      = "70% 70%",
                    })
                  end'')
              ];
            };
          };
        };
    };
}
