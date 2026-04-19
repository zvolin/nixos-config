{ ... }:

{
  flake.modules.homeManager.hypridle = { pkgs, ... }: {
    services.hypridle =
      let
        brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        loginctl = "${pkgs.systemd}/bin/loginctl";
        hyprctl = "${pkgs.hyprland}/bin/hyprctl";
        hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      in
      {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || ${hyprlock}";
            before_sleep_cmd = "${loginctl} lock-session";
            after_sleep_cmd = "${hyprctl} dispatch dpms on";
            # respect inhibit requests from media players (firefox, mpv, etc.)
            ignore_dbus_inhibit = false;
            ignore_systemd_inhibit = false;
          };

          listener = [
            # 1. slight dim (5 min)
            {
              timeout = 300;
              on-timeout = "${brightnessctl} -s set 15%";
              on-resume = "${brightnessctl} -r";
            }
            # 2. very dim + keyboard backlight off (9 min)
            {
              timeout = 540;
              on-timeout = "${brightnessctl} set 5%";
              on-resume = "${brightnessctl} -r";
            }
            {
              timeout = 540;
              on-timeout = "touchbar-kbd-sync off";
              on-resume = "touchbar-kbd-sync restore";
            }
            # 3. lock screen (10 min)
            {
              timeout = 600;
              on-timeout = "pidof hyprlock || ${hyprlock}";
            }
            # 4. screen off (15 min)
            {
              timeout = 900;
              on-timeout = "${hyprctl} dispatch dpms off";
              on-resume = "${hyprctl} dispatch dpms on";
            }
            # 5. suspend (30 min)
            {
              timeout = 1800;
              on-timeout = "${systemctl} suspend";
            }
          ];
        };
      };
  };
}
