{ ... }:
{
  flake.modules.homeManager.cleanup =
    { ... }:
    {
      programs.claude-code.skills.cleanup = ./files;
      programs.codex.skills.cleanup = ./files;
    };
}
