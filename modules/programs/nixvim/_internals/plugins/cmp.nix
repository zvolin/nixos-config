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
          keyword_length = 4;
          # Words from other open buffers can also be suggested
          # (raw is needed so it passes function and not string)
          option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
        }
      ];
      mapping = {
        "<CR>" = "cmp.mapping.confirm({ select = false })";
        "<Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, {'i', 's'})
        '';
        "<S-Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, {'i', 's'})
        '';
        "<C-j>" = "cmp.mapping.scroll_docs(-4)";
        "<C-k>" = "cmp.mapping.scroll_docs(4)";
      };
      window = {
        completion.__raw = "cmp.config.window.bordered()";
        documentation.__raw = "cmp.config.window.bordered()";
      };
      preselect = "cmp.PreselectMode.None";
    };
  };
}
