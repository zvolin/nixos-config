{ ... }:

{
  programs.nixvim.plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings = {
      snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
      sources = [
        { name = "path"; }
        { name = "nvim_lsp"; }
        {
          name = "luasnip";
          keyword_length = 2;
        }
        {
          name = "buffer";
          keyword_length = 3;
          # Words from other open buffers can also be suggested
          # (raw is needed so it passes function and not string)
          option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
        }
      ];
      mapping = {
        "<CR>" = "cmp.mapping.confirm({ select = false })";
        "<Tab>" = "require('lsp-zero').cmp_action().luasnip_supertab()";
        "<S-Tab>" = "require('lsp-zero').cmp_action().luasnip_shift_supertab()";
        "<C-j>" = "cmp.mapping.scroll_docs(-4)";
        "<C-k>" = "cmp.mapping.scroll_docs(4)";
      };
      formatting.__raw = "require('lsp-zero').cmp_format({ details = false })";
      window = {
        completion.__raw = "cmp.config.window.bordered()";
        documentation.__raw = "cmp.config.window.bordered()";
      };
      preselect = "cmp.PreselectMode.None";
    };
  };
}
