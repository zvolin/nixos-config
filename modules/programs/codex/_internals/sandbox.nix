{
  pkgs,
  lib,
  ...
}:
let
  jail = import ../../_jail.nix { inherit pkgs lib; };
  claudeTools = import ./claude-tools.nix { inherit pkgs lib jail; };

  codexJail = jail.mkJail {
    name = "codex";
    policy = jail.clients.codex;
    extraEnv = [
      "AI_SESSION_PROJECT"
      "AI_SESSION_TAB"
    ];
    preCreateDirs = [
      ".codex"
      ".agents"
      ".claude"
    ];
    preCreateFiles = [ ".claude.json" ];
    pathPrefix = [ claudeTools.claudeShim ];
  };

  codex-wrapped = codexJail.wrapper // {
    inherit (pkgs.codex) version;
    meta = (pkgs.codex.meta or { }) // {
      mainProgram = "codex";
    };
  };
in
{
  programs.codex.package = codex-wrapped;
}
