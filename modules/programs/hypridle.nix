{ ... }:
{
  flake.modules.homeManager.hypridle =
    { pkgs, ... }:
    let
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      loginctl = "${pkgs.systemd}/bin/loginctl";
      hyprctl = "${pkgs.hyprland}/bin/hyprctl";
      hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      pgrep = "${pkgs.procps}/bin/pgrep";
      pkill = "${pkgs.procps}/bin/pkill";
      touch = "${pkgs.coreutils}/bin/touch";
      rm = "${pkgs.coreutils}/bin/rm";
      markerPath = "$XDG_RUNTIME_DIR/amphetamine";
    in
    {
      home.packages = [
        # Amphetamine mode: runtime marker at $XDG_RUNTIME_DIR/amphetamine.
        # The guard decides skip-or-run per listener; save/restore stay paired
        # through a per-cycle sentinel.
        (pkgs.writeShellScriptBin "amphetamine-guard" ''
          class="$1"; shift
          [ "$1" = "--" ] && shift
          marker="${markerPath}"
          case "$class" in
            screen)
              if [ -e "$marker" ] && ! ${pgrep} -x hyprlock >/dev/null; then
                exit 0
              fi
              ;;
            sleep)
              if [ -e "$marker" ]; then
                exit 0
              fi
              ;;
            *)
              echo "Usage: amphetamine-guard {screen|sleep} -- <command...>" >&2
              exit 1
              ;;
          esac
          exec "$@"
        '')
        (pkgs.writeShellScriptBin "amphetamine-save" ''
          sentinel="$XDG_RUNTIME_DIR/amphetamine-$1"; shift
          [ "$1" = "--" ] && shift
          "$@" && ${touch} "$sentinel"
        '')
        (pkgs.writeShellScriptBin "amphetamine-restore" ''
          sentinel="$XDG_RUNTIME_DIR/amphetamine-$1"; shift
          [ "$1" = "--" ] && shift
          if [ -e "$sentinel" ]; then
            "$@"
            ${rm} -f "$sentinel"
          fi
        '')
        (pkgs.writeShellScriptBin "hyprlock-once" ''
          ${pgrep} -x hyprlock >/dev/null || exec ${hyprlock}
        '')
        (pkgs.writeShellScriptBin "amphetamine-toggle" ''
          marker="${markerPath}"
          if [ -e "$marker" ]; then
            ${rm} -f "$marker"
          else
            ${touch} "$marker"
          fi
          ${pkill} -RTMIN+9 waybar || true
        '')
      ];

      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "hyprlock-once";
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
              on-timeout = "amphetamine-guard screen -- amphetamine-save dim -- ${brightnessctl} -s set 15%";
              on-resume = "amphetamine-restore dim -- ${brightnessctl} -r";
            }
            # 2. very dim (9 min)
            {
              timeout = 540;
              on-timeout = "amphetamine-guard screen -- amphetamine-save dim-more -- ${brightnessctl} set 5%";
              on-resume = "amphetamine-restore dim-more -- ${brightnessctl} -r";
            }
            # 3. keyboard backlight off (9 min)
            {
              timeout = 540;
              on-timeout = "amphetamine-guard screen -- amphetamine-save kbd -- touchbar-kbd-sync off";
              on-resume = "amphetamine-restore kbd -- touchbar-kbd-sync restore";
            }
            # 4. auto-lock (10 min)
            {
              timeout = 600;
              on-timeout = "amphetamine-guard screen -- hyprlock-once";
            }
            # 5. screen off (15 min)
            {
              timeout = 900;
              on-timeout = "amphetamine-guard screen -- ${hyprctl} dispatch dpms off";
              on-resume = "${hyprctl} dispatch dpms on";
            }
            # 6. suspend (30 min)
            {
              timeout = 1800;
              on-timeout = "amphetamine-guard sleep -- ${systemctl} suspend";
            }
          ];
        };
      };
    };
}
