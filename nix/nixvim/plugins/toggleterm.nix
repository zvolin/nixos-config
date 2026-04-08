{ ... }:

{
  programs.nixvim = {
    plugins.toggleterm = {
      enable = true;

      settings = {
        direction = "float";
        # open_mapping = "[[<C-t>]]";
        terminal_mappings = false;
        float_opts.border = "curved";
        # https://github.com/akinsho/toggleterm.nvim/issues/473#issuecomment-1703818003
        persist_mode = false;
        start_in_insert = true;
      };
    };

    # extraPlugins = [
    #   (pkgs.vimUtils.buildVimPlugin {
    #     name = "toggleterm-manager";
    #     src = pkgs.fetchFromGitHub {
    #       owner = "ryanmsnyder";
    #       repo = "toggleterm-manager.nvim";
    #       rev = "31318b85a7cc20bf50ce32aedf4e835844133863";
    #       hash = "sha256-7t61kcqeOS9hPXc9y88Sa8D0ZXIqxCXtxFQzmHKFJ8c=";
    #     };
    #   })
    # ];

    extraConfigLua = ''
      local toggleterm = require("toggleterm")
      local terminal = require("toggleterm.terminal")
      local ui = require("toggleterm.ui")

      local claude_terms = {}
      local claude_last_opened = 1
      local claude_regex = vim.regex("term://.*claude.*#toggleterm#")

      local function _term_toggle(id)
        -- helper to get current terminal
        local get_term = function()
          local bufnr = vim.api.nvim_get_current_buf()
          return terminal.find(function(term) return term.bufnr and bufnr == term.bufnr end)
        end

        -- if terminal belongs to claude shell, toggle it out first
        if claude_regex:match_str(vim.api.nvim_buf_get_name(0)) then
          local term = get_term()
          if term then
            pcall(function() term:close() end)
          end
        end

        toggleterm.toggle(id)

        -- update regular term's name with its id
        local term = get_term()
        if term then
          local name = "-" .. term.id .. "-"
          if term.display_name ~= name then
            term.display_name = name
            ui.update_float(term)
          end
        end
      end

      local function _term_toggle_claude(id)
        if not id or id < 1 then
          id = claude_last_opened
        end
        claude_last_opened = id

        -- allocate new claude term if needed, clean up stale refs
        local term = claude_terms[id]
        if term and term.bufnr and not vim.api.nvim_buf_is_valid(term.bufnr) then
          claude_terms[id] = nil
          term = nil
        end
        if not term then
          local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          local name = "vim:" .. project .. " #" .. id
          claude_terms[id] = terminal.Terminal:new({
            cmd = "claude",
            id = 1000 + id,
            display_name = "-claude" .. id .. "-",
            hidden = true,
            env = { CLAUDE_SESSION_NAME = name },
          })
        end

        pcall(function() claude_terms[id]:toggle() end)
      end

      local make_bind = function(mode, bind, f, opts)
        vim.keymap.set(mode, bind, f, vim.tbl_extend("force", { silent = true }, opts or {}))
      end

      local term_binds = function(shell_bind, claude_bind, id)
        if shell_bind then
          make_bind({ "n", "i" }, shell_bind, function() _term_toggle(id()) end)
        end
        if claude_bind then
          make_bind({ "n", "i" }, claude_bind, function() _term_toggle_claude(id()) end)
        end
        vim.api.nvim_create_autocmd("TermEnter", {
          pattern = [[term://*toggleterm#*]],
          callback = function()
            if shell_bind then
              make_bind("t", shell_bind, function() _term_toggle(id()) end)
            end
            if claude_bind then
              make_bind("t", claude_bind, function() _term_toggle_claude(id()) end)
            end
          end
        })
      end

      term_binds("<C-t>", "<C-S-t>", function() return vim.v.count end)
      -- for i = 1, 9 do
      --   term_binds("<C-M-t>" .. i, "<C-M-t>c" .. i, function() return i end)
      --   term_binds(nil, "<C-M-S-t>" .. i, function() return i end)
      -- end
    '';
  };
}
