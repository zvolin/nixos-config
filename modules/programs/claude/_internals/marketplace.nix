{ ... }:
{
  programs.claude-code.settings = {
    enabledPlugins = {
      "rust-analyzer-lsp@claude-plugins-official" = true;
    };
  };
}
