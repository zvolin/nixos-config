{ lib, pkgs, config, ... }:

{
  programs.nixvim.plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings = {
      snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
      sources = [
        { name = "path"; }
        { name = "nvim_lsp"; }
        { name = "luasnip"; }
        {
          name = "buffer";
          # Words from other open buffers can also be suggested
          option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
        }
      ];
      mapping = {
        "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })";
        "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 's' })";
      };
      preselect = "cmp.PreselectMode.None";
    };
  };
}
