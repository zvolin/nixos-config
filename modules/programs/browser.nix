{...}: {
  flake.modules.homeManager.browser = {
    pkgs,
    config,
    ...
  }: {
    # https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };

    stylix.targets.firefox.profileNames = ["default"];

    programs.chromium = {
      enable = true;
      package = pkgs.chromium;

      commandLineArgs = [
        "--ozone-platform-hint=auto" # wayland support
      ];
    };
  };
}
