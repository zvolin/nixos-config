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

      # extraOpts = {
      #   BrowserSignin = 0;
      #   SyncDisabled = true;
      #   PasswordManagerEnabled = false;
      #   CloudReportingEnabled = false;
      #   SafeBrowsingEnabled = false;
      #   ReportSafeBrowsingData = false;
      #   DefaultBrowserSettingEnabled = false;
      # };
    };
  };
}
