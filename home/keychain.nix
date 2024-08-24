{ pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };

  services.ssh-agent.enable = true;

  services.gpg-agent = {
    enable = true;

    defaultCacheTtl = 84000;
    maxCacheTtl = 84000;

    pinentryPackage = pkgs.pinentry-curses;
  };
}
