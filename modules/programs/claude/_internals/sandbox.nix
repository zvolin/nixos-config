{
  pkgs,
  lib,
  ...
}:
let
  jail = import ../../_jail.nix { inherit pkgs lib; };
  codexTools = import ./codex-tools.nix { inherit pkgs lib jail; };

  claudeJail = jail.mkJail {
    name = "claude";
    policy = jail.clients.claude;
    preCreateDirs = [
      ".claude"
      ".codex"
      ".agents"
    ];
    preCreateFiles = [ ".claude.json" ];
    extraEnv = [
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
      "CLAUDE_SESSION_NAME"
    ];
    pathPrefix = [ codexTools.codexWrap ];
  };

  claude-wrapped = claudeJail.wrapper // {
    inherit (pkgs.claude-code) version;
    meta = (pkgs.claude-code.meta or { }) // {
      mainProgram = "claude";
    };
  };
in
{
  programs.claude-code.package = claude-wrapped;
}
