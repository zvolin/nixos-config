{ ... }:

{
  programs.git = {
    enable = true;

    ignores = [
      "**/.claude/worktrees/"
      "**/.claude/settings.local.json"
      "**/docs/plans/"
      "**/docs/insights/"
      "**/.direnv"
      "**/CLAUDE.local.md"
      "**/HANDOFF.md"
    ];

    signing.key = "9DD9C8FD06750734";
    signing.signByDefault = true;
    signing.format = "openpgp";
  };
}
