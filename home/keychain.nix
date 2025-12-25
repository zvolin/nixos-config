{ pkgs, lib, ... }:

let
  # Pinentry wrapper that uses loopback in Claude, curses otherwise
  pinentry-switcher = pkgs.writeShellApplication {
    name = "pinentry-switcher";
    runtimeInputs = [ pkgs.pinentry-curses ];
    text = ''
      if [ -n "''${CLAUDECODE:-}" ]; then
        exec pinentry-curses --loopback "$@"
      else
        exec pinentry-curses "$@"
      fi
    '';
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".addKeysToAgent = "yes";
  };

  services.ssh-agent.enable = true;

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;

    defaultCacheTtl = 84000;
    maxCacheTtl = 84000;

    # Use our switcher instead of plain pinentry
    pinentry.package = null;
    extraConfig = ''
      pinentry-program ${lib.getExe pinentry-switcher}
      allow-loopback-pinentry
    '';
  };
}
