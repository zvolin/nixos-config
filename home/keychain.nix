{ pkgs, ... }:

{
  programs.keychain = {
    enable = true;
    keys = [ "id_ed25519" "9DD9C8FD06750734" ];
    agents = [ "gpg" "ssh" ];
  };

  services.gpg-agent = {
    defaultCacheTtl = 84000;
    maxCacheTtl = 84000;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
