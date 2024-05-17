{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nil # nix
    ruff # python
    nodePackages.bash-language-server
    nodePackages.typescript-language-server
  ];

  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      cmp-nvim-lsp
      lsp-zero-nvim
      luasnip
      nvim-cmp
      nvim-lspconfig
    ];

    extraConfigLua = ''
      local lsp_zero = require('lsp-zero')

      -- enable default behavior
      lsp_zero.on_attach(function(client, bufnr)
        lsp_zero.default_keymaps({
          buffer = bufnr,
          preserve_mappings = false
        })
        lsp_zero.buffer_autoformat()
      end)

      -- setup signs
      lsp_zero.set_sign_icons({
        error = '✘',
        warn = '▲',
        hint = '⚑',
        info = '»'
      })

      -- setup language servers
      require('lspconfig').bashls.setup({})
      require('lspconfig').nil_ls.setup({})
      require('lspconfig').ruff.setup({})
      require('lspconfig').tsserver.setup({})

      -- pass the capabilities to rustaceanvim to not conflict
      vim.g.rustaceanvim = {
        server = {
          capabilities = lsp_zero.get_capabilities()
        },
      }
    '';
  };
}
