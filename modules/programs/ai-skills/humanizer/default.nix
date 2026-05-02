{inputs, ...}: {
  flake.modules.homeManager.humanizer = {...}: {
    programs.claude-code.skills.humanizer = "${inputs.humanizer}";
    programs.codex.skills.humanizer = "${inputs.humanizer}";
  };
}
