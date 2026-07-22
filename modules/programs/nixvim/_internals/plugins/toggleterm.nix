{ pkgs, ... }:
let
  ai-launch = import ./ai-launch.nix { inherit pkgs; };
in
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
      local function set_shell_last(id) shell_last = id end
      local function shell_label(_, id) return "shell-" .. id end

      local ai_terms = {}
      local ai_last = 1
      local ai_callback_last = 0
      local function set_ai_last(id) ai_last = id end
      local function ai_label(term, id) return ((term and term.agent) or "ai") .. "-" .. id end

      ---------------------------------------------------------------
      -- Helpers
      ---------------------------------------------------------------

      local function in_term_tab()
        return term_tabpage
          and vim.api.nvim_tabpage_is_valid(term_tabpage)
          and vim.api.nvim_get_current_tabpage() == term_tabpage
      end

      local function next_id(terms)
        local highest = 0
        for id in pairs(terms) do
          if id > highest then highest = id end
        end
        return highest + 1
      end

      local function has_valid_buffer(term)
        return term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)
      end

      local function compact_terms(terms, set_last, label_for)
        local members = {}
        for id, term in pairs(terms) do
          table.insert(members, { old_id = id, term = term })
        end
        table.sort(members, function(a, b) return a.old_id < b.old_id end)

        for id in pairs(terms) do terms[id] = nil end
        for id, member in ipairs(members) do
          member.term.logical_id = id
          member.term.display_name = label_for(member.term, id)
          terms[id] = member.term
        end
        set_last(#members)
        vim.schedule(function() vim.cmd("redrawtabline") end)
      end

      local function remove_term(term, terms, set_last, label_for)
        local removed_id = term.logical_id
        if not removed_id or terms[removed_id] ~= term then return nil end

        terms[removed_id] = nil
        compact_terms(terms, set_last, label_for)
        return terms[removed_id] or terms[#terms]
      end

      ---------------------------------------------------------------
      -- Exit handling
      ---------------------------------------------------------------

      local function find_live_replacement(group_replacement, other_terms)
        if has_valid_buffer(group_replacement) then return group_replacement end
        for _, term in pairs(other_terms) do
          if has_valid_buffer(term) then return term end
        end
        return nil
      end

      local function handle_term_exit(term, terms, set_last, label_for, other_terms)
        if term.exit_detached then
          term.exit_detached = nil
          return
        end
        local group_replacement = remove_term(term, terms, set_last, label_for)
        local replacement = find_live_replacement(group_replacement, other_terms)
        local bufnr = term.bufnr
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

        local to_close = {}
        local to_replace = {}
        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
          if vim.api.nvim_win_is_valid(win) then
            local tab_wins = vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win))
            if #tab_wins > 1 then
              table.insert(to_close, win)
            else
              table.insert(to_replace, win)
            end
          end
        end

        for _, win in ipairs(to_close) do
          if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        end
        for _, win in ipairs(to_replace) do
          if vim.api.nvim_win_is_valid(win) then
            if replacement then
              vim.api.nvim_win_set_buf(win, replacement.bufnr)
            elseif in_term_tab() and source_tab and vim.api.nvim_tabpage_is_valid(source_tab) then
              vim.api.nvim_set_current_tabpage(source_tab)
            end
          end
        end
        if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
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

        -- AI terminals (ascending order, lowest IDs closest to center)
        local ai_entries = {}
        for id, t in pairs(ai_terms) do
          if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
            local hl = entry_hl(t.bufnr)
            table.insert(ai_entries, { id = id, str = hl .. " " .. t.display_name .. " %#BufferLineFill#" })
          end
        end
        table.sort(ai_entries, function(a, b) return a.id < b.id end)

        local left = {}
        for _, p in ipairs(shell_entries) do table.insert(left, p.str) end
        local right = {}
        for _, p in ipairs(ai_entries) do table.insert(right, p.str) end

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
        if not id or id < 1 then id = next_id(shell_terms) end
        local term = shell_terms[id]
        if not term then
          term = terminal.Terminal:new({
            display_name = shell_label(nil, id),
            direction = "tab",
            hidden = true,
            close_on_exit = false,
            on_exit = function(t)
              vim.schedule(function()
                handle_term_exit(t, shell_terms, set_shell_last, shell_label, ai_terms)
              end)
            end,
          })
          term.logical_id = id
          shell_terms[id] = term
          set_shell_last(math.max(shell_last, id))
        end
        return term
      end

      local function get_ai(id)
        if not id or id < 1 then id = next_id(ai_terms) end
        local term = ai_terms[id]
        if not term then
          local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          ai_callback_last = ai_callback_last + 1
          local callback_id = ai_callback_last
          term = terminal.Terminal:new({
            cmd = "${ai-launch}/bin/ai-launch "
              .. callback_id
              .. " "
              .. id
              .. " "
              .. vim.fn.shellescape(project),
            display_name = ai_label(nil, id),
            direction = "tab",
            hidden = true,
            close_on_exit = false,
            on_exit = function(t)
              vim.schedule(function()
                handle_term_exit(t, ai_terms, set_ai_last, ai_label, shell_terms)
              end)
            end,
          })
          term.logical_id = id
          term.callback_id = callback_id
          term.agent = "ai"
          ai_terms[id] = term
          set_ai_last(math.max(ai_last, id))
        end
        return term
      end

      function _G.ai_rename(callback_id, agent)
        for _, term in pairs(ai_terms) do
          if term.callback_id == callback_id then
            term.agent = agent
            term.display_name = ai_label(term, term.logical_id)
            vim.schedule(function() vim.cmd("redrawtabline") end)
            break
          end
        end
        return ""
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

      -- Telescope picker over a single terminal group.
      -- terms is keyed by logical id (1-9); the key, not term.id, is what
      -- focus_term expects.
      local function pick_term(get_term_fn, terms)
        local function is_live(t) return t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) end
        local entries = {}
        for id, term in pairs(terms) do
          if is_live(term) then
            table.insert(entries, { logical_id = id, term = term })
          end
        end
        if #entries == 0 then
          vim.notify("No terminals in this group", vim.log.levels.INFO)
          return
        end
        -- Stable initial order by id; fzf-native reorders once the user types.
        table.sort(entries, function(a, b) return a.logical_id < b.logical_id end)

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local previewers = require("telescope.previewers")

        pickers.new({}, {
          prompt_title = "Terminals",
          sorting_strategy = "ascending",
          finder = finders.new_table({
            results = entries,
            entry_maker = function(e)
              return {
                value = e.term,
                display = e.term.display_name,
                ordinal = e.term.display_name,
                logical_id = e.logical_id,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          previewer = previewers.new_buffer_previewer({
            define_preview = function(self, entry)
              local lines = {}
              if is_live(entry.value) then
                -- Copy only the tail: bounds cost on long-lived shells and
                -- shows the most recent output. strict_indexing=false clamps
                -- a shorter buffer safely.
                lines = vim.api.nvim_buf_get_lines(entry.value.bufnr, -500, -1, false)
              end
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              -- Scroll to the last line so the most recent output is visible.
              local win = self.state.winid
              if win and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_set_cursor(win, { math.max(1, #lines), 0 })
              end
            end,
          }),
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local entry = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if not entry then return end
              -- The snapshot is stale if the terminal exited while the picker
              -- was open; re-validate so selection reaches the previewed
              -- terminal rather than silently spawning a fresh one.
              local term = entry.value
              if not is_live(term) then
                vim.notify("Terminal no longer exists", vim.log.levels.INFO)
                return
              end
              focus_term(get_term_fn, entry.logical_id)
            end)
            return true
          end,
        }):find()
      end

      -- Split current window and open a new terminal
      local function split_term(get_term_fn, terms, direction)
        if not in_term_tab() then return end
        vim.cmd(direction == "v" and "vsplit" or "split")
        local id = next_id(terms)
        show_term(get_term_fn(id))
      end

      local function close_current_term(terms, set_last, label_for, other_terms)
        if not in_term_tab() then return end
        local bufnr = vim.api.nvim_get_current_buf()
        local term = terminal.find(function(candidate) return candidate.bufnr == bufnr end)
        if not term then return end
        local id = term.logical_id
        if not id or terms[id] ~= term then return end
        local replacement = find_live_replacement(
          remove_term(term, terms, set_last, label_for),
          other_terms
        )
        if replacement then
          show_term(replacement)
        elseif source_tab and vim.api.nvim_tabpage_is_valid(source_tab) then
          vim.api.nvim_set_current_tabpage(source_tab)
        end
        term.exit_detached = true
        term:shutdown()
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
      bind({ "n", "i", "t" }, "<C-t><C-t>", function()
        toggle_tab(get_shell, shell_last)
      end)
      bind({ "n", "i", "t" }, "<C-t><Tab>", function() pick_term(get_shell, shell_terms) end)
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
        close_current_term(shell_terms, set_shell_last, shell_label, ai_terms)
      end)

      -- Remap increment since <C-a> is taken by the AI prefix
      bind("n", "g<C-a>", "<C-a>")

      -- AI: <C-a> prefix
      bind({ "n", "i", "t" }, "<C-a><C-a>", function()
        toggle_tab(get_ai, ai_last)
      end)
      bind({ "n", "i", "t" }, "<C-a><Tab>", function() pick_term(get_ai, ai_terms) end)
      for i = 1, 9 do
        bind({ "n", "i", "t" }, "<C-a>" .. i, function() focus_term(get_ai, i) end)
      end
      bind("t", "<C-a>v", function() split_term(get_ai, ai_terms, "v") end)
      bind("t", "<C-a>s", function() split_term(get_ai, ai_terms, "h") end)
      bind("t", "<C-a>n", function()
        if not in_term_tab() then return end
        show_term(get_ai(next_id(ai_terms)))
      end)
      bind("t", "<C-a>x", function()
        close_current_term(ai_terms, set_ai_last, ai_label, shell_terms)
      end)
    '';
  };
}
