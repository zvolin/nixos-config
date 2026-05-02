{...}: {
  flake.modules.homeManager.research = {...}: {
    programs.claude-code.skills.research = ./files;
    programs.codex.skills.research = ./files;
  };
}
