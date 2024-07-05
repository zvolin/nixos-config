{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gopls # go
    nil # nix
    nixd # nix
    nixfmt-rfc-style
    pyright # python
    nodePackages.bash-language-server
    nodePackages.typescript-language-server
  ];

  programs.nixvim = {
    plugins.fidget.enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      cmp-nvim-lsp
      lsp-zero-nvim
      luasnip
      nvim-cmp
      nvim-lspconfig
    ];

    extraConfigLua = ''
      local lsp_zero = require('lsp-zero')

      -- run when server attaches to buffer
      lsp_zero.on_attach(function(client, bufnr)
        -- bind default lsp keymaps like gd
        lsp_zero.default_keymaps({
          buffer = bufnr,
          -- override if keymap is taken
          preserve_mappings = false
        })

        -- default autoformat with lsp
        lsp_zero.buffer_autoformat()

        -- bind nvim-navic
        if client.server_capabilities.documentSymbolProvider and
            client.name ~= "nixd" then -- only attach to nil for nix
          require('nvim-navic').attach(client, bufnr)
        end
      end)

      -- enable inlay hints
      vim.lsp.inlay_hint.enable(false, { 0 })

      -- setup signs
      lsp_zero.extend_lspconfig({
        sign_text = {
          error = '✘',
          warn = '▲',
          hint = '⚑',
          info = '»'
        },
      })

      -- setup language servers
      lsp_zero.setup_servers({
        'bashls',
        'gopls',
        'nixd',
        'pyright',
        'ts_ls',
      })

      require('lspconfig').nil_ls.setup({
        settings = {
          ['nil'] = {
            formatting = { command = { "nixfmt" } },
          },
        },
      })

      -- pass the capabilities to rustaceanvim to not conflict
      vim.g.rustaceanvim = {
        server = {
          capabilities = lsp_zero.get_capabilities(),
          default_settings = {
            ['rust-analyzer'] = {
              checkOnSave = {
                command = 'clippy'
              },
              cargo = {
                -- uncomment for wasm
                -- target = 'wasm32-unknown-unknown',
              },
            },
          },
        },
      }

      -- Decorate floating windows
      -- vim.api.nvim_set_hl(0, "FloatBorder", { link = "@function.method" })
      local lsp_util_open_floating_preview = vim.lsp.util.open_floating_preview
      function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        opts = opts or {}
        opts.border = opts.border or 'rounded'
        return lsp_util_open_floating_preview(contents, syntax, opts, ...)
      end
    '';
  };
}
