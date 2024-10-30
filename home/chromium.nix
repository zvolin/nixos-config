{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;

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
}
