{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [
    inputs.nvf.nixosModules.default
  ];

  programs.nvf = {
    enable = true;
    enableManpages = true;

    settings.vim = {
      viAlias = false;
      vimAlias = false;
      lsp = {
        enable = true;
      };
      spellcheck = {
        enable = false;
      };

      lsp = {
        formatOnSave = true;
        lspkind.enable = false;
        lightbulb.enable = true;
        lspsaga.enable = false;
        trouble.enable = true;
        lspSignature.enable = true;
        otter-nvim.enable = true;
        lsplines.enable = true;
        nvim-docs-view.enable = true;
      };

      debugger = {
        nvim-dap = {
          enable = true;
          ui.enable = true;
        };
      };

      # This section does not include a comprehensive list of available language modules.
      # To list all available language module options, please visit the nvf manual.
      languages = {
        enableLSP = true;
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;

        # Languages that will be supported in default and maximal configurations.
        nix.enable = true;
        markdown.enable = true;

        # Languages that are enabled in the maximal configuration.
        bash.enable = true;
        clang.enable = true;
        css.enable = true;
        html.enable = true;
        sql.enable = true;
        java.enable = false;
        kotlin.enable = true;
        ts.enable = true;
        go.enable = true;
        lua.enable = true;
        zig.enable = false;
        python.enable = true;
        typst.enable = false;
        rust = {
          enable = true;
          crates.enable = true;
        };

        # Language modules that are not as common.
        assembly.enable = false;
        astro.enable = false;
        nu.enable = false;
        csharp.enable = false;
        julia.enable = false;
        vala.enable = false;
        scala.enable = false;
        r.enable = false;
        gleam.enable = false;
        dart.enable = false;
        ocaml.enable = false;
        elixir.enable = false;
        haskell.enable = false;
        ruby.enable = false;

        tailwind.enable = false;
        svelte.enable = false;

        # Nim LSP is broken on Darwin and therefore
        # should be disabled by default. Users may still enable
        # `vim.languages.vim` to enable it, this does not restrict
        # that.
        # See: <https://github.com/PMunch/nimlsp/issues/178#issue-2128106096>
        nim.enable = false;
      };

      visuals = {
        nvim-scrollbar.enable = true;
        nvim-web-devicons.enable = true;
        nvim-cursorline.enable = true;
        cinnamon-nvim.enable = true;
        fidget-nvim.enable = true;

        highlight-undo.enable = true;
        indent-blankline.enable = true;

        # Fun
        cellular-automaton.enable = false;
      };

      statusline = {
        lualine = {
          enable = true;
          theme = "auto";
        };
      };

      theme = {
        enable = true;
        name = "base16";
        transparent = true;
        base16-colors = with config.lib.stylix.colors.withHashtag; {
          base00 = base00;
          base01 = base01;
          base02 = base02;
          base03 = base03;
          base04 = base04;
          base05 = base05;
          base06 = base06;
          base07 = base07;
          base08 = base08;
          base09 = base09;
          base0A = base0A;
          base0B = base0B;
          base0C = base0C;
          base0D = base0D;
          base0E = base0E;
          base0F = base0F;
        };
      };

      autopairs.nvim-autopairs.enable = true;

      autocomplete.nvim-cmp.enable = true;
      snippets.luasnip.enable = true;

      filetree = {
        neo-tree = {
          enable = true;
        };
      };

      tabline = {
        nvimBufferline.enable = true;
      };

      treesitter.context.enable = true;

      binds = {
        whichKey.enable = true;
        cheatsheet.enable = true;
      };

      telescope.enable = true;

      git = {
        enable = true;
        gitsigns.enable = true;
        gitsigns.codeActions.enable = false; # throws an annoying debug message
      };

      minimap = {
        minimap-vim.enable = false;
        codewindow.enable = true; # lighter, faster, and uses lua for configuration
      };

      dashboard = {
        dashboard-nvim.enable = false;
        alpha.enable = true;
      };

      notify = {
        nvim-notify.enable = true;
      };

      projects = {
        project-nvim.enable = true;
      };

      utility = {
        ccc.enable = false;
        vim-wakatime.enable = false;
        icon-picker.enable = true;
        surround.enable = true;
        diffview-nvim.enable = true;
        yanky-nvim.enable = false;
        motion = {
          hop.enable = true;
          leap.enable = true;
          precognition.enable = false;
        };

        images = {
          image-nvim.enable = false;
        };
      };

      notes = {
        obsidian.enable = false; # FIXME: neovim fails to build if obsidian is enabled
        neorg.enable = false;
        orgmode.enable = false;
        mind-nvim.enable = false;
        todo-comments.enable = true;
      };

      terminal = {
        toggleterm = {
          enable = true;
          lazygit.enable = true;
        };
      };

      ui = {
        borders.enable = true;
        noice.enable = false;
        colorizer.enable = true;
        modes-nvim.enable = false; # the theme looks terrible with catppuccin
        illuminate.enable = true;
        breadcrumbs = {
          enable = true;
          navbuddy.enable = true;
        };
        smartcolumn = {
          enable = false;
          setupOpts.custom_colorcolumn = {
            # this is a freeform module, it's `buftype = int;` for configuring column position
            nix = "110";
            ruby = "120";
            java = "130";
            go = [
              "90"
              "130"
            ];
          };
        };
        fastaction.enable = true;
      };

      assistant = {
        chatgpt.enable = false;
        copilot = {
          enable = false;
          cmp.enable = true;
        };
      };

      session = {
        nvim-session-manager.enable = false;
      };

      gestures = {
        gesture-nvim.enable = false;
      };

      comments = {
        comment-nvim.enable = true;
      };

      presence = {
        neocord.enable = false;
      };
    };
  };
}
