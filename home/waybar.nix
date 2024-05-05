{ lib, pkgs, config, ... }:

let
  palette = config.colorScheme.palette;
  font-size = size: text: ''<span font-size="${builtins.toString size}pt">${text}</span>'';
  big = text: "${font-size 10.5 text}";
  tiny = text: "${font-size 5.5 text}";
in {
  home.packages = [ pkgs.waybar ];

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
          format = " ";
        };

        "hyprland/workspaces" = {
          active-only = false;
          all-outputs = true;
          show-special = false;
          on-click = "activate";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          format = "{name}";
        };

        "hyprland/window" = {
          format = "{class}# {}";
	        max-length = 60;
          separate-outputs = false;
          rewrite = {
	          # firefox rule
            "firefox# (.*) — Mozilla Firefox" = "${big ""}  $1";
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
          format = "${big " "}{:%d.%m.%Y %H:%M}";
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
        font-family: FiraCode Nerd Font;
        font-size: 8.5pt;
	      min-height: 0px;
	      padding: 0px;
	      margin: 0px;
      }

      tooltip {
        background: rgba(43, 48, 59, 0.5);
        border: 1px solid rgba(100, 114, 125, 0.5);
      }

      tooltip label {
        color: #${palette.base06};
      }

      window#waybar {
        color: #${palette.base05};
        background: #${palette.base00};
        padding-top: 1px;
        padding-bottom: 1px;
      }

      #custom-logo {
        font-size: 11pt;
        margin-left: 5px;
        margin-right: 5px;
      }

      #workspaces {
        background: #${palette.base0E};
        color: #${palette.base02};
	      margin: 4px;
        padding-left: 8px;
        padding-right: 8px;
        border-radius: 6px;
      }

      /* disable default hover effect */
      #workspaces button:hover {
        background-image: none;
      }

      /* add 'jumping' of hovered label */
      #workspaces button:hover:not(.active) label {
        padding-bottom: 2px;
        padding-left: 1px;
      }

      #workspaces button label {
        font-size: 7.5pt;
        color: #${palette.base02};
      }

      #workspaces button.active label {
        font-weight: bold;
      }

      #window {
        padding-left: 15px;
        padding-right: 10px;
      }
      
      #network, #perf, #media, #battery {
        color: #${palette.base02};
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
        background: #${palette.base0E};
      }

      #perf {
        background: #${palette.base0E};
      }

      #media {
        background: #${palette.base0E};
      }

      #battery {
        background: #${palette.base0E};
      }
    '';
  };
}
