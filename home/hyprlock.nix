{ lib, config, ... }:

let
  colors = config.lib.stylix.colors;
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 5; # seconds before lock actually engages after showing
      };

      background = lib.mkForce [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 5;
          brightness = 0.75;
        }
      ];

      label = [
        # Time
        {
          text = "$TIME";
          font_size = 64;
          font_family = "FiraCode Nerd Font Bold";
          color = "rgb(${colors.base05})";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          text = "cmd[update:3600000] date '+%A, %B %d'";
          font_size = 20;
          font_family = "FiraCode Nerd Font";
          color = "rgb(${colors.base04})";
          position = "0, 20";
          halign = "center";
          valign = "center";
        }
        # Keyboard layout
        {
          text = "$LAYOUT";
          font_size = 14;
          font_family = "FiraCode Nerd Font";
          color = "rgb(${colors.base04})";
          position = "0, -100";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = lib.mkForce [
        {
          size = "300, 50";
          outline_thickness = 2;
          dots_size = 0.25;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = "rgb(${colors.base0D})";
          inner_color = "rgb(${colors.base01})";
          font_color = "rgb(${colors.base05})";
          fade_on_empty = false;
          placeholder_text = "";
          hide_input = false;
          rounding = 8;
          check_color = "rgb(${colors.base0B})";
          fail_color = "rgb(${colors.base08})";
          fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
          fail_transition = 300;
          position = "0, -40";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
