{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gopls # go
    nil # nix
    nixd # nix
    nixfmt
    pyright # python
    nodePackages.bash-language-server
    nodePackages.typescript-language-server
  ];

  programs.nixvim = {
    plugins.fidget.enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      cmp-nvim-lsp
      luasnip
      nvim-cmp
    ];

    extraConfigLua = ''
      -- Setup diagnostic signs
      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = '✘',
            [vim.diagnostic.severity.WARN] = '▲',
            [vim.diagnostic.severity.HINT] = '⚑',
            [vim.diagnostic.severity.INFO] = '»',
          },
        },
      })

      -- LSP capabilities with cmp_nvim_lsp
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Default config for all LSP servers
      vim.lsp.config('*', {
        root_markers = { '.git' },
        capabilities = capabilities,
      })

      -- Configure individual language servers
      vim.lsp.config('bashls', {
        cmd = { 'bash-language-server', 'start' },
        filetypes = { 'sh', 'bash' },
      })

      vim.lsp.config('clangd', {
        cmd = { 'clangd' },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
        root_markers = { 'compile_commands.json', '.clangd', '.git' },
      })

      vim.lsp.config('gopls', {
        cmd = { 'gopls' },
        filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
        root_markers = { 'go.mod', 'go.work', '.git' },
      })

      vim.lsp.config('nixd', {
        cmd = { 'nixd' },
        filetypes = { 'nix' },
        root_markers = { 'flake.nix', '.git' },
      })

      vim.lsp.config('nil_ls', {
        cmd = { 'nil' },
        filetypes = { 'nix' },
        root_markers = { 'flake.nix', '.git' },
        settings = {
          ['nil'] = {
            formatting = { command = { 'nixfmt' } },
          },
        },
      })

      vim.lsp.config('pyright', {
        cmd = { 'pyright-langserver', '--stdio' },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' },
      })

      vim.lsp.config('ts_ls', {
        cmd = { 'typescript-language-server', '--stdio' },
        filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
        root_markers = { 'package.json', 'tsconfig.json', '.git' },
      })

      -- Enable all language servers
      vim.lsp.enable({
        'bashls',
        'clangd',
        'gopls',
        'nixd',
        'nil_ls',
        'pyright',
        'ts_ls',
      })

      -- LSP attach callback
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local bufnr = args.buf

          -- Standard vim keymaps (buffer-local, only active with LSP)
          local opts = { buffer = bufnr }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)

          vim.diagnostic.config {
            virtual_text = {
              severity = { min = vim.diagnostic.severity.INFO, },
              spacing = 5,
            },
            underline = { severity = { min = vim.diagnostic.severity.INFO }, },
            float = {
              source = true,
            },
          }

          -- Auto format on save
          if client and client.supports_method('textDocument/formatting') then
            vim.api.nvim_create_autocmd('BufWritePre', {
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.format({ bufnr = bufnr })
              end,
            })
          end

          -- Bind nvim-navic (only for servers with documentSymbol, excluding nixd)
          if client and client.server_capabilities.documentSymbolProvider and
              client.name ~= 'nixd' then
            require('nvim-navic').attach(client, bufnr)
          end
        end,
      })

      -- Enable inlay hints (disabled by default)
      vim.lsp.inlay_hint.enable(false, { 0 })

      -- Rustaceanvim configuration (handles rust-analyzer separately)
      vim.g.rustaceanvim = {
        server = {
          capabilities = capabilities,
          default_settings = {
            ['rust-analyzer'] = {
              checkOnSave = true,
              check = {
                command = 'clippy'
              },
              cargo = {
                features = 'all',
              },
            },
          },
        },
      }

      -- Decorate floating windows with rounded borders
      local lsp_util_open_floating_preview = vim.lsp.util.open_floating_preview
      function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        opts = opts or {}
        opts.border = opts.border or 'rounded'
        return lsp_util_open_floating_preview(contents, syntax, opts, ...)
      end
    '';
  };
}
