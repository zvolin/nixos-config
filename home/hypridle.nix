{ config, pkgs, lib, ... }:

{
  services.hypridle = let
    brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    loginctl = "${pkgs.systemd}/bin/loginctl";
    hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  in {
    enable = true;
    settings = {
      general = {
          # avoid starting multiple hyprlock instances.
          lock_cmd = "pidof ${hyprlock} || ${hyprlock}";
          # lock before suspend.
          before_sleep_cmd = "${loginctl} lock-session";
          # to avoid having to press a key twice to turn on the display.
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
      };

      listener = [
        {
          timeout = 150; # 2.5 min
          on-timeout = "${brightnessctl} -s set 10"; # set monitor backlight to minimum, avoid 0 on OLED monitor.
          on-resume = "${brightnessctl} -r"; # monitor backlight restore.
        }
        # turn off keyboard backlight.
        {
          timeout = 150; # 2.5min.
          on-timeout = "${brightnessctl} -sd kbd_backlight set 0";
          on-resume = "${brightnessctl} -rd kbd_backlight";
        }
        # lock screen when timeout has passed
        {
          timeout = 300; # 5min
          on-timeout = "${loginctl} lock-session";
        }
        # screen off when timeout has passed
        {
          timeout = 330; # 5.5min
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume = "${hyprctl} dispatch dpms on";
        }
        # suspend when timeout has passed
        {
          timeout = 900; # 15min
          on-timeout = "${systemctl} suspend";
        }
      ];
    };
  };
}
