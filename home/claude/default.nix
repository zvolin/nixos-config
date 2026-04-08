{ ... }:

{
  imports = [
    ./agents.nix
    ./skills.nix
    ./hooks.nix
    ./permissions.nix
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

      # Preferences

      - commits should usually follow "conventional commits" and only inclued header line, unless
        the repository has some other well-defined commit message structure
      - Do not add Co-Authored-By to git commits
    '';

    # Settings for ~/.claude/settings.json
    settings = {
      # Plugins
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "superpowers@superpowers-marketplace" = true;
        "skill-codex@skill-codex" = true;
      };

      # Third-party plugin marketplaces
      extraKnownMarketplaces = {
        superpowers-marketplace = {
          source = {
            source = "github";
            repo = "obra/superpowers-marketplace";
          };
        };
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
