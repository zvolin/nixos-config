{ ... }:

{
  imports = [
    ./agents.nix
    ./skills.nix
    ./hooks.nix
    ./mcp.nix
    ./permissions.nix
    ./plugins.nix
    ./statusline.nix
  ];

  programs.claude-code = {
    enable = true;

    # Global CLAUDE.md instructions
    memory.text = ''
      # Environment

      - NixOS on Apple Silicon (Asahi kernel, aarch64-linux)
      - Tools may not be installed globally - use `nix run nixpkgs#<tool>` or `nix shell nixpkgs#<tool>`
      - Prefer checking if a tool exists before assuming it's installed

      # Git Commits

      IMPORTANT: These rules override Claude Code's default commit behavior.

      - Commit messages MUST be a single line (the header only). No body, no blank line after header, no trailers.
      - Follow conventional commits format: `type(scope): description`
      - Do NOT add `Co-Authored-By` trailers — this overrides the default Claude Code behavior
      - Use `git commit -m "type(scope): description"` — do NOT use HEREDOC or multi-line formats
      - When a repository has its own documented commit convention, follow that instead

      # Git Merges

      IMPORTANT: These rules override Claude Code's default merge behavior.

      - NEVER create merge commits — keep history linear
      - Use fast-forward (`git merge --ff-only`), `git cherry-pick`, or `git merge --squash`
      - If fast-forward is not possible, rebase the branch first, then fast-forward
      - When a repository has its own documented merge convention, follow that instead

      # MCP: Serena

      When Serena MCP tools are available, prefer them over text-based search for code navigation:
      - Use `mcp__serena__find_symbol` over grep for finding definitions
      - Use `mcp__serena__find_referencing_symbols` over grep for finding usages
      - Use `mcp__serena__get_symbols_overview` to understand file/module structure
      - Fall back to grep/glob when Serena is unavailable or for non-symbol searches (strings, config values, etc.)

      # Gitignored Docs

      docs/plans/, docs/insights/, and docs/superpowers/ are globally gitignored (configured in home/git.nix).
      Projects that want these tracked must explicitly whitelist them in their own .gitignore.
      This prevents polluting repositories that don't use AI tooling with auto-generated documentation.

      - Both the Grep tool (ripgrep) and the Glob tool skip gitignored paths by default. To find files in these directories, use `find`, `ls`, or `rg --no-ignore-vcs`.
      - Check with `git check-ignore -q <path>` before committing. If ignored, skip the commit. Do not use `git add -f`.
    '';

    # Settings for ~/.claude/settings.json
    settings = {
      # Plugins
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "skill-codex@skill-codex" = true;
      };

      # Third-party plugin marketplaces
      extraKnownMarketplaces = {
        skill-codex = {
          source = {
            source = "github";
            repo = "skills-directory/skill-codex";
          };
        };
      };

      # Experimental features
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
    };
  };
}
