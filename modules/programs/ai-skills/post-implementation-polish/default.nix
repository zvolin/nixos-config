{ ... }:
{
  flake.modules.homeManager.post-implementation-polish =
    { ... }:
    {
      programs.claude-code.skills.post-implementation-polish = ./files;
      programs.codex.skills.post-implementation-polish = ./files;
    };
}
