{ pkgs, ... }:

{
  pam.sessionVariables = {
    SSH_AGENT_PID = "DEFAULT=";
    SSH_AUTH_SOCK = "DEFAULT=\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
  };

  services.gpg-agent = {
    defaultCacheTtl = 84000;
    maxCacheTtl = 84000;

    defaultCacheTtlSsh = 84000;
    maxCacheTtlSsh = 84000;

    pinentryPackage = pkgs.pinentry-curses;
  };
}
