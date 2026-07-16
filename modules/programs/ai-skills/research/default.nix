{ ... }:
{
  flake.modules.homeManager.research =
    { ... }:
    {
      programs.claude-code.skills.research = ./files;
      programs.codex.skills.research = ./files;

      # claude-code.agents takes the file contents as a string; codex.agents
      # accepts a path directly and parses the frontmatter at build time.
      programs.claude-code.agents.research-coverage-reviewer = builtins.readFile ./files/agents/coverage-reviewer.md;
      programs.claude-code.agents.research-validation-reviewer = builtins.readFile ./files/agents/validation-reviewer.md;

      programs.codex.agents.research-coverage-reviewer = ./files/agents/coverage-reviewer.md;
      programs.codex.agents.research-validation-reviewer = ./files/agents/validation-reviewer.md;
    };
}
