{ ... }:

{
  flake.modules.homeManager.browser = { pkgs, ... }: {
    # https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265
    programs.firefox = {
      enable = true;
    };

    stylix.targets.firefox.profileNames = [ "default" ];

    programs.chromium = {
      enable = true;
      package = pkgs.chromium;

      commandLineArgs = [
        "--ozone-platform-hint=auto" # wayland support
      ];
    };
  };
}
