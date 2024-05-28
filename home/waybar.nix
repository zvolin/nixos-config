{ config, ... }:

let
  size = config.stylix.fonts.sizes.desktop;
  sized = size: text: ''<span font-size="${builtins.toString size}pt">${text}</span>'';
  big = text: "${sized (size * 1.1) text}";
  small = text: "${sized (size * 0.8) text}";
  tiny = text: "${sized (size * 0.6) text}";
in {
  programs.waybar = {
    enable = true;

    settings = [
      {
        layer = "bottom";
        fixed-center = true;
        only-active = false;

        modules-left = [
          "custom/logo"
          "hyprland/workspaces"
          "hyprland/window"
        ];

        modules-center = [ "clock" ];

        modules-right = [
          "tray"
          "network"
          "group/perf"
          "group/media"
          "battery"
        ];

        "custom/logo" = {
          format = "${big ""}";
        };

        "hyprland/workspaces" = {
          active-only = false;
          all-outputs = true;
          show-special = false;
          on-click = "activate";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          format = "${small "{name}"}";
        };

        "hyprland/window" = {
          format = "{class}# {}";
          max-length = 60;
          separate-outputs = false;
          rewrite = {
            # firefox rule
            "firefox# (.*?)( — )?Mozilla Firefox" = "${big ""}  $1";
            # kitty rule
            "kitty# (.*)" = "  $1";
            # remove the class prefix if it doesn't match any previous rules
            # must explicitely define that previous rules don't match, or it would
            # just hide them
            "(?!firefox|kitty).*?# (.*)" = "$1";
          };
        };

        clock = {
          interval = 1;
          format = "${big "  "}{:%d.%m.%Y %H:%M}";
        };

        tray = {
          icon-size = 21;
          spacing = 10;
        };

        network = {
          tooltip = true;
          interval = 5;
          format-wifi = "${big " "}${tiny "{signalStrength}% "}{essid}";
          format-disconnected = "disconnected";
          on-click = "";
          tooltip-format = "{ifname} {ipaddr}";
        };

        "group/perf" = {
          orientation = "inherit";
          modules = [
            "cpu"
            "memory"
            "disk"
          ];
        };

        # 󰾅   󰍛        
        cpu = {
          interval = 10;
          format = "${big " "}{usage}%";
        };

        memory = {
          interval = 10;
          format = "${big " "}{used:0.1f}G";
          tooltip-format = "ram: {used:0.1f}G/{total:0.1f}G, swap: {swapUsed:0.1f}G/{swapTotal:0.1f}G";
        };

        disk = {
          interval = 30;
          format = "${big " "}{percentage_used}%";
          tooltip-format = "Used: {percentage_used}% {used}/{total}\nFree: {percentage_free}% {free}/{total}";
          path = "/";
        };

        "group/media" = {
          orientation = "inherit";
          modules = [
            "backlight"
            "wireplumber"
          ];
        };

        backlight = {
          interval = 10.0;
          format = "${big "󰥟 "}{percent}%";
          scroll-step = 1.0;
          tooltip = false;
        };

        wireplumber = {
          format = "${big " "} {volume}%";
          format-muted = "${big ""}";
          max-volume = 120;
          scroll-step = 0.2;
        };

        battery = {
          format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          format = "${big "{icon}"}";
          format-charging = "${big "{icon}󱐋"}";
          interval = 15;
          states = {
            warning = 30;
            critical = 15;
          };
        };
      }
    ];

    style = ''
      * {
        border: none;
        min-height: 0px;
        padding: 0px;
        margin: 0px;
        font-family: FiraCode Nerd Font;
      }

      tooltip label {
      }

      window#waybar {
        padding-top: 1px;
        padding-bottom: 1px;
      }

      #custom-logo {
        margin-left: 5px;
        margin-right: 10px;
      }

      #workspaces {
        background: @base0D;
        margin: 4px;
        padding-left: 8px;
        padding-right: 8px;
        border-radius: 6px;
      }

      #workspaces button {
        color: @base00;
        border-radius: 0px;
      }

      /* disable default hover effect */
      #workspaces button:hover {
        box-shadow: none;
        text-shadow: none;
        background: none;
        transition: none;
        background-image: none;
      }

      /* add 'jumping' of hovered label */
      #workspaces button:hover:not(.active) label {
        padding-bottom: 2px;
        padding-left: 1px;
      }

      /* override borders added by stylix */
      window#waybar .modules-left #workspaces button,
      window#waybar .modules-left #workspaces button.active,
      window#waybar .modules-left #workspaces button.focused {
        margin-top: 3px;
        border-bottom-width: 2px;
      }
      window#waybar .modules-left #workspaces button.active,
      window#waybar .modules-left #workspaces button.focused {
        border-bottom-color: @base00;
      }

      #workspaces button.active label {
        font-weight: bold;
      }

      #window {
        margin-left: 10px;
        margin-right: 10px;
      }

      #network, #perf, #media, #battery {
        color: @base00;
        margin-top: 3px;
        margin-bottom: 3px;
        margin-right: 4px;
        padding-left: 8px;
        padding-right: 8px;
        border-radius: 6px;
      }

      #perf widget:not(:last-child) label,
      #media widget:not(:last-child) label {
        margin-right: 10px;
      }

      #network {
        background: @base0D;
      }

      #perf {
        background: @base0B;
      }

      #media {
        background: @base0D;
      }

      #battery {
        background: @base08;
      }
    '';
  };
}
