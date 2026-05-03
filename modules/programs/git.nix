{...}: {
  flake.modules.homeManager.git = {...}: {
    programs.git = {
      enable = true;

      settings.user = {
        name = "zvolin";
        email = "mac.zwolinski@gmail.com";
      };

      ignores = [
        "**/.claude/"
        "**/.worktrees"
        "**/docs/plans/"
        "**/docs/insights/"
        "**/docs/superpowers/"
        "**/.serena/"
        "**/.direnv"
        "**/.envrc"
        "**/CLAUDE.local.md"
        "**/HANDOFF.md"
        "**/AGENTS.md"
        "**/AGENTS.override.md"
        "**/.agents/"
        "**/.codex"
      ];

      signing.key = "9DD9C8FD06750734";
      signing.signByDefault = true;
      signing.format = "openpgp";
    };
  };
}
