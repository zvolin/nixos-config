{ ... }:
{
  flake.modules.homeManager.browser =
    {
      pkgs,
      config,
      ...
    }:
    let
      firefoxDesktop = "firefox.desktop";
    in
    {
      # https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265
      programs.firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };

      stylix.targets.firefox.profileNames = [ "default" ];

      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/http" = firefoxDesktop;
        "x-scheme-handler/https" = firefoxDesktop;
        "text/html" = firefoxDesktop;
        "application/xhtml+xml" = firefoxDesktop;
      };

      programs.chromium = {
        enable = true;
        package = pkgs.chromium;

        commandLineArgs = [
          "--ozone-platform-hint=auto" # wayland support
        ];
      };
    };
}
