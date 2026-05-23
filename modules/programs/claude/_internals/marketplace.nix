{ ... }:
{
  programs.claude-code.settings = {
    enabledPlugins = {
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "skill-codex@skill-codex" = true;
    };
    extraKnownMarketplaces = {
      skill-codex = {
        source = {
          source = "github";
          repo = "skills-directory/skill-codex";
        };
      };
    };
  };
}
