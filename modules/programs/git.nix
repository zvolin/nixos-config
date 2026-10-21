{ ... }:
{
  flake.modules.homeManager.git =
    { pkgs, lib, ... }:
    {
      programs.git = {
        enable = true;

        settings.user = {
          name = "zvolin";
          email = "mac.zwolinski@gmail.com";
        };

        settings.gpg.program = lib.getExe pkgs.gnupg;

        ignores = [
          "**/.claude/"
          "**/.worktrees"
          "**/docs/plans/"
          "**/docs/insights/"
          "**/docs/superpowers/"
          "**/docs/research/"
          "**/docs/LLM_CONTEXT.md"
          "**/docs/architecture-reports/"
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

        # Sign by default. The signing identity (format + key) is per-host and
        # set in each host's config.
        signing.signByDefault = true;
      };
    };
}
