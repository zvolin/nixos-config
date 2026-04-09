{ ... }:

{
  programs.nixvim = {
    plugins.toggleterm = {
      enable = true;

      settings = {
        terminal_mappings = false;
        # https://github.com/akinsho/toggleterm.nvim/issues/473#issuecomment-1703818003
        persist_mode = false;
        start_in_insert = true;
      };
    };

    extraConfigLua = ''
      local terminal = require("toggleterm.terminal")

      ---------------------------------------------------------------
      -- State
      ---------------------------------------------------------------
      local term_tabpage = nil -- managed terminal tabpage handle
      local source_tab = nil   -- tab to return to on toggle

      local shell_terms = {}
      local shell_last = 1

      local claude_terms = {}
      local claude_last = 1

      ---------------------------------------------------------------
      -- Helpers
      ---------------------------------------------------------------

      local function in_term_tab()
        return term_tabpage
          and vim.api.nvim_tabpage_is_valid(term_tabpage)
          and vim.api.nvim_get_current_tabpage() == term_tabpage
      end

      -- Find the lowest unused ID in a terms table
      local function next_id(terms)
        local id = 1
        while terms[id] and terms[id].bufnr
              and vim.api.nvim_buf_is_valid(terms[id].bufnr) do
          id = id + 1
        end
        return id
      end

      ---------------------------------------------------------------
      -- Exit handling
      ---------------------------------------------------------------

      local function find_live_replacement()
        for _, t in pairs(shell_terms) do
          if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) and t:is_open() then
            return t
          end
        end
        for _, t in pairs(claude_terms) do
          if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) and t:is_open() then
            return t
          end
        end
        return nil
      end

      local function handle_term_exit(term, terms, id)
        terms[id] = nil

        local bufnr = term.bufnr
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

        -- Collect windows before mutating to avoid invalidation mid-loop
        local wins = vim.fn.win_findbuf(bufnr)
        local to_close = {}
        local to_replace = {}

        for _, win in ipairs(wins) do
          if vim.api.nvim_win_is_valid(win) then
            local tab_wins = vim.api.nvim_tabpage_list_wins(
              vim.api.nvim_win_get_tabpage(win)
            )
            if #tab_wins > 1 then
              table.insert(to_close, win)
            else
              table.insert(to_replace, win)
            end
          end
        end

        for _, win in ipairs(to_close) do
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end

        for _, win in ipairs(to_replace) do
          if vim.api.nvim_win_is_valid(win) then
            local replacement = find_live_replacement()
            if replacement then
              vim.api.nvim_win_set_buf(win, replacement.bufnr)
            elseif in_term_tab() then
              if source_tab and vim.api.nvim_tabpage_is_valid(source_tab) then
                vim.api.nvim_set_current_tabpage(source_tab)
              end
            end
          end
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end

      ---------------------------------------------------------------
      -- Terminal tabline
      ---------------------------------------------------------------

      vim.api.nvim_set_hl(0, "TermSelected", { link = "BufferLineBufferSelected" })
      vim.api.nvim_set_hl(0, "TermVisible", { link = "BufferLineBufferVisible" })
      vim.api.nvim_set_hl(0, "TermInactive", { link = "BufferLineBackground" })
      vim.api.nvim_set_hl(0, "TermSeparator", { link = "BufferLineBackground" })

      -- Visible width of a tabline string (strips %#HlGroup# and %* sequences)
      local function tabline_width(s)
        local stripped = s:gsub("%%#[^#]*#", ""):gsub("%%*", "")
        return vim.fn.strdisplaywidth(stripped)
      end

      function _G.term_tabline()
        -- Determine which buffers are visible and which is focused
        local focused_buf = nil
        local visible_bufs = {}
        if term_tabpage and vim.api.nvim_tabpage_is_valid(term_tabpage) then
          local wins = vim.api.nvim_tabpage_list_wins(term_tabpage)
          local focused_win = vim.api.nvim_get_current_win()
          for _, win in ipairs(wins) do
            local buf = vim.api.nvim_win_get_buf(win)
            if win == focused_win then
              focused_buf = buf
            end
            visible_bufs[buf] = true
          end
        end

        local function entry_hl(bufnr)
          if bufnr == focused_buf then return "%#TermSelected#" end
          if visible_bufs[bufnr] then return "%#TermVisible#" end
          return "%#TermInactive#"
        end

        -- Shell terminals (reverse order, highest IDs farthest from center)
        local shell_entries = {}
        for id, t in pairs(shell_terms) do
          if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
            local hl = entry_hl(t.bufnr)
            table.insert(shell_entries, { id = id, str = hl .. " " .. t.display_name .. " %#BufferLineFill#" })
          end
        end
        table.sort(shell_entries, function(a, b) return a.id > b.id end)

        -- Claude terminals (ascending order, lowest IDs closest to center)
        local claude_entries = {}
        for id, t in pairs(claude_terms) do
          if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
            local hl = entry_hl(t.bufnr)
            table.insert(claude_entries, { id = id, str = hl .. " " .. t.display_name .. " %#BufferLineFill#" })
          end
        end
        table.sort(claude_entries, function(a, b) return a.id < b.id end)

        local left = {}
        for _, p in ipairs(shell_entries) do table.insert(left, p.str) end
        local right = {}
        for _, p in ipairs(claude_entries) do table.insert(right, p.str) end

        local lstr = table.concat(left)
        local rstr = table.concat(right)
        local fill = "%#BufferLineFill#"

        if #left == 0 and #right == 0 then
          return fill
        elseif #left == 0 or #right == 0 then
          -- Single group: center as-is
          local content = #left > 0 and lstr or rstr
          return fill .. "%=" .. content .. "%="
        else
          -- Both groups: pad shorter side so separator stays centered
          local sep = "%#TermSeparator# · %#BufferLineFill#"
          local lw = tabline_width(lstr)
          local rw = tabline_width(rstr)
          local pad = string.rep(" ", math.abs(lw - rw))
          if lw < rw then
            lstr = fill .. pad .. lstr
          elseif rw < lw then
            rstr = rstr .. pad
          end
          return fill .. "%=" .. lstr .. sep .. rstr .. "%="
        end
      end

      function _G.custom_tabline()
        if in_term_tab() then
          return term_tabline()
        end
        -- bufferline.nvim exposes nvim_bufferline as a global Lua function
        if nvim_bufferline then return nvim_bufferline() end
        return ""
      end

      vim.o.tabline = '%!v:lua.custom_tabline()'

      ---------------------------------------------------------------
      -- Terminal constructors
      ---------------------------------------------------------------

      local function get_shell(id)
        if not id or id < 1 then id = shell_last end
        shell_last = id
        local term = shell_terms[id]
        if term and (not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr)) then
          shell_terms[id] = nil
          term = nil
        end
        if not term then
          term = terminal.Terminal:new({
            id = id,
            display_name = "shell-" .. id,
            direction = "tab",
            hidden = true,
            close_on_exit = false,
            on_exit = function(t)
              vim.schedule(function() handle_term_exit(t, shell_terms, id) end)
            end,
          })
          shell_terms[id] = term
        end
        return term
      end

      local function get_claude(id)
        if not id or id < 1 then id = claude_last end
        claude_last = id
        local term = claude_terms[id]
        if term and (not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr)) then
          claude_terms[id] = nil
          term = nil
        end
        if not term then
          local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          local name = "vim:" .. project .. " #" .. id
          term = terminal.Terminal:new({
            cmd = "claude",
            id = 1000 + id,
            display_name = "claude-" .. id,
            direction = "tab",
            hidden = true,
            close_on_exit = false,
            on_exit = function(t)
              vim.schedule(function() handle_term_exit(t, claude_terms, id) end)
            end,
            env = { CLAUDE_SESSION_NAME = name },
          })
          claude_terms[id] = term
        end
        return term
      end

      ---------------------------------------------------------------
      -- Tab & window management
      ---------------------------------------------------------------

      -- Show a terminal buffer in the current window
      local function show_term(term)
        if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
          term:spawn()
        end
        vim.api.nvim_set_current_buf(term.bufnr)
        vim.cmd("startinsert")
      end

      -- Ensure the terminal tab exists and switch to it.
      -- Returns true if a new tab was created.
      local function ensure_term_tab()
        if term_tabpage and vim.api.nvim_tabpage_is_valid(term_tabpage) then
          vim.api.nvim_set_current_tabpage(term_tabpage)
          return false
        end
        vim.cmd("tabnew | setlocal bufhidden=wipe")
        term_tabpage = vim.api.nvim_get_current_tabpage()
        return true
      end

      -- Toggle the terminal tab (switch to it or back to code)
      local function toggle_tab(get_term_fn, default_id)
        local term = get_term_fn(default_id)
        local current_buf = vim.api.nvim_get_current_buf()

        if in_term_tab() and term.bufnr and current_buf == term.bufnr then
          -- Already viewing this terminal — toggle off, return to source
          if source_tab and vim.api.nvim_tabpage_is_valid(source_tab) then
            vim.api.nvim_set_current_tabpage(source_tab)
            return
          end
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            if tab ~= term_tabpage then
              vim.api.nvim_set_current_tabpage(tab)
              return
            end
          end
          -- No code tab exists, create one
          vim.cmd("tabnew")
        else
          -- Switch to terminal tab and show the requested terminal
          if not in_term_tab() then
            source_tab = vim.api.nvim_get_current_tabpage()
          end
          ensure_term_tab()
          show_term(term)
        end
      end

      -- Focus a specific terminal by ID
      local function focus_term(get_term_fn, id)
        if not in_term_tab() then
          source_tab = vim.api.nvim_get_current_tabpage()
          ensure_term_tab()
        end
        show_term(get_term_fn(id))
      end

      -- Split current window and open a new terminal
      local function split_term(get_term_fn, terms, direction)
        if not in_term_tab() then return end
        vim.cmd(direction == "v" and "vsplit" or "split")
        local id = next_id(terms)
        show_term(get_term_fn(id))
      end

      -- When the terminal tab is closed externally, clean up state.
      -- Don't jump — neovim auto-selects an adjacent tab, and toggle_tab /
      -- handle_term_exit handle explicit returns to source_tab.
      vim.api.nvim_create_autocmd("TabClosed", {
        callback = function()
          if term_tabpage and not vim.api.nvim_tabpage_is_valid(term_tabpage) then
            term_tabpage = nil
          end
          if source_tab and not vim.api.nvim_tabpage_is_valid(source_tab) then
            source_tab = nil
          end
        end,
      })

      ---------------------------------------------------------------
      -- Keybindings
      ---------------------------------------------------------------

      local bind = function(modes, lhs, rhs)
        vim.keymap.set(modes, lhs, rhs, { silent = true })
      end

      -- Shell: <C-t> prefix
      bind({ "n", "i", "t" }, "<C-t><C-t>", function() toggle_tab(get_shell) end)
      for i = 1, 9 do
        bind({ "n", "i", "t" }, "<C-t>" .. i, function() focus_term(get_shell, i) end)
      end
      bind("t", "<C-t>v", function() split_term(get_shell, shell_terms, "v") end)
      bind("t", "<C-t>s", function() split_term(get_shell, shell_terms, "h") end)
      bind("t", "<C-t>n", function()
        if not in_term_tab() then return end
        show_term(get_shell(next_id(shell_terms)))
      end)
      bind("t", "<C-t>x", function()
        if not in_term_tab() then return end
        local bufnr = vim.api.nvim_get_current_buf()
        local term = terminal.find(function(t) return t.bufnr == bufnr end)
        if term then term:shutdown() end
      end)

      -- Remap increment since <C-a> is taken by claude prefix
      bind("n", "g<C-a>", "<C-a>")

      -- Claude: <C-a> prefix
      bind({ "n", "i", "t" }, "<C-a><C-a>", function() toggle_tab(get_claude) end)
      for i = 1, 9 do
        bind({ "n", "i", "t" }, "<C-a>" .. i, function() focus_term(get_claude, i) end)
      end
      bind("t", "<C-a>v", function() split_term(get_claude, claude_terms, "v") end)
      bind("t", "<C-a>s", function() split_term(get_claude, claude_terms, "h") end)
      bind("t", "<C-a>n", function()
        if not in_term_tab() then return end
        show_term(get_claude(next_id(claude_terms)))
      end)
      bind("t", "<C-a>x", function()
        if not in_term_tab() then return end
        local bufnr = vim.api.nvim_get_current_buf()
        local term = terminal.find(function(t) return t.bufnr == bufnr end)
        if term then term:shutdown() end
      end)
    '';
  };
}
