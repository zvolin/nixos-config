{ ... }:

{
  imports = [
    ./agents.nix
    ./skills.nix
    ./hooks.nix
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

    # MCP servers
    # mcpServers = {
    #   filesystem = {
    #     command = "npx";
    #     args = [ "-y" "@anthropic/mcp-filesystem-server" "/home/zwolin" ];
    #   };
    # };
  };
}
