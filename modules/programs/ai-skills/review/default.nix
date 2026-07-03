{ ... }:
{
  flake.modules.homeManager.review =
    { ... }:
    {
      programs.claude-code.skills.review = ./files;
      programs.codex.skills.review = ./files;
    };
}
