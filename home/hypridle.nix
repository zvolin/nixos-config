{ pkgs, config, ... }:

let
  colors = config.lib.stylix.colors;
in
{
  # before hyprlock#434 is fixed
  programs.swaylock = {
    enable = true;
    settings = {
      color = colors.base01;
      font-size = 24;
      indicator-idle-visible = false;
      indicator-radius = 100;
      line-color = colors.base0D;
      show-failed-attempts = true;
    };
  };

  services.hypridle =
    let
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      loginctl = "${pkgs.systemd}/bin/loginctl";
      hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    in
    # hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    {
      enable = true;
      settings = {
        general = {
          # avoid starting multiple hyprlock instances.
          lock_cmd = "pidof swaylock || swaylock";
          # lock before suspend.
          before_sleep_cmd = "${loginctl} lock-session";
          # to avoid having to press a key twice to turn on the display.
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
        };

        listener = [
          {
            timeout = 600; # 10 min
            on-timeout = "${brightnessctl} -s set 10"; # set monitor backlight to minimum, avoid 0 on OLED monitor.
            on-resume = "${brightnessctl} -r"; # monitor backlight restore.
          }
          # turn off keyboard backlight.
          {
            timeout = 600; # 10 min.
            on-timeout = "${brightnessctl} -sd kbd_backlight set 0";
            on-resume = "${brightnessctl} -rd kbd_backlight";
          }
          # screen off when timeout has passed
          {
            timeout = 750; # 12.5 min
            on-timeout = "${hyprctl} dispatch dpms off";
            on-resume = "${hyprctl} dispatch dpms on";
          }
          # lock screen when timeout has passed
          {
            timeout = 900; # 15 min
            on-timeout = "${loginctl} lock-session";
          }
          # suspend when timeout has passed
          {
            timeout = 1200; # 20 min
            on-timeout = "${systemctl} suspend";
          }
        ];
      };
    };
}
