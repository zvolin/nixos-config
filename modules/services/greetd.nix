{ ... }:

{
  flake.modules.nixos.greetd = { config, pkgs, lib, ... }:
    let
      tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
      desktops = "${config.services.displayManager.sessionData.desktops}/share";
    in
    {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = lib.concatStringsSep " " [
            "${tuigreet}"
            "--time"
            "--remember"
            "--remember-user-session"
            "--asterisks"
            "--user-menu"
            "--sessions ${desktops}/wayland-sessions:${desktops}/xsessions"
          ];
          user = "greeter";
        };
      };

      systemd.tmpfiles.rules = [
        "L /var/cache/tuigreet - - - - /persist/var/cache/tuigreet"
      ];
      systemd.tmpfiles.settings."10-tuigreet" = {
        "/persist/var/cache/tuigreet" = {
          d = {
            user = "greeter";
            group = "greeter";
            mode = "0755";
          };
        };
      };
    };
}
