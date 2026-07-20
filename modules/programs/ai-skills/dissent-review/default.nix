{ ... }:
{
  flake.modules.homeManager.dissent-review =
    { ... }:
    {
      programs.claude-code.skills.dissent-review = ./files;
      programs.codex.skills.dissent-review = ./files;
    };
}
