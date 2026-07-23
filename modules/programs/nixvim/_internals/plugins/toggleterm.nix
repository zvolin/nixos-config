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

      local shell_terms = {}
      local shell_last = 1
      local function set_shell_last(id) shell_last = id end
      local function shell_label(id) return "shell-" .. id end

      local function next_id()
        local highest = 0
        for id in pairs(shell_terms) do
          if id > highest then highest = id end
        end
        return highest + 1
      end

      local function has_valid_buffer(term)
        return term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)
      end

      local function is_open(term)
        return term and term.is_open and term:is_open()
      end

      -- Toggle the current shell, or the last shell used outside one.
      local function resolve_toggle_target(default_id)
        local current_buf = vim.api.nvim_get_current_buf()
        local current_term = terminal.find(function(candidate)
          return candidate.bufnr == current_buf
        end)
        local id = current_term and current_term.logical_id
        if id and shell_terms[id] == current_term and has_valid_buffer(current_term) then
          return id
        end
        return default_id
      end

      local function compact_terms()
        local last_term = shell_terms[shell_last]
        local members = {}
        for id, term in pairs(shell_terms) do
          table.insert(members, { old_id = id, term = term })
        end
        table.sort(members, function(a, b) return a.old_id < b.old_id end)
        for id in pairs(shell_terms) do shell_terms[id] = nil end
        for id, member in ipairs(members) do
          member.term.logical_id = id
          member.term.display_name = shell_label(id)
          shell_terms[id] = member.term
        end
        -- Preserve the last shell through renumbering.
        if last_term then
          set_shell_last(last_term.logical_id)
        else
          set_shell_last(math.max(math.min(shell_last, #members), 1))
        end
      end

      local function live_replacement(excluded)
        for _, term in pairs(shell_terms) do
          if term ~= excluded and has_valid_buffer(term) then return term end
        end
        return nil
      end

      -- false means another exit handler already removed this shell.
      local function detach_term(term)
        local id = term.logical_id
        if not id or shell_terms[id] ~= term then return false end
        local replacement = live_replacement(term)
        shell_terms[id] = nil
        compact_terms()
        return replacement
      end

      local function close_others(target)
        for _, term in pairs(shell_terms) do
          if term ~= target and is_open(term) then term:close() end
        end
      end

      local function show_shell(term)
        close_others(term)
        if not is_open(term) then term:open() end
        set_shell_last(term.logical_id)
      end

      local function handle_shell_exit(term)
        if term.exit_detached then
          term.exit_detached = nil
          return
        end
        local was_open = is_open(term)
        local replacement = detach_term(term)
        if replacement == false then return end
        if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
          vim.api.nvim_buf_delete(term.bufnr, { force = true })
        end
        if was_open and replacement and has_valid_buffer(replacement) then
          show_shell(replacement)
        end
      end

      local FLOAT_SIZE_RATIO = 0.85

      local function get_shell(id)
        if not id or id < 1 then id = next_id() end
        local term = shell_terms[id]
        if not term then
          term = terminal.Terminal:new({
            display_name = shell_label(id),
            direction = "float",
            float_opts = {
              border = "curved",
              width = function() return math.floor(vim.o.columns * FLOAT_SIZE_RATIO) end,
              height = function() return math.floor(vim.o.lines * FLOAT_SIZE_RATIO) end,
            },
            hidden = true,
            close_on_exit = false,
            on_exit = function(t)
              vim.schedule(function() handle_shell_exit(t) end)
            end,
          })
          term.logical_id = id
          shell_terms[id] = term
          set_shell_last(math.max(shell_last, id))
        end
        return term
      end

      local function toggle_shell()
        local term = get_shell(resolve_toggle_target(shell_last))
        if is_open(term) then
          term:close()
        else
          show_shell(term)
        end
      end

      local function focus_shell(id)
        show_shell(get_shell(id))
      end

      local function new_shell()
        show_shell(get_shell(next_id()))
      end

      local function close_current()
        local buf = vim.api.nvim_get_current_buf()
        local term = terminal.find(function(candidate) return candidate.bufnr == buf end)
        if not term then return end
        local replacement = detach_term(term)
        if replacement == false then return end
        term.exit_detached = true
        term:shutdown()
        if replacement and has_valid_buffer(replacement) then
          show_shell(replacement)
        end
      end

      local function set_preview_cursor(win, lines)
        if #lines > 0 and win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_set_cursor(win, { #lines, 0 })
        end
      end

      local function pick_shell()
        local function is_live(t) return t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) end
        local entries = {}
        for id, term in pairs(shell_terms) do
          if is_live(term) then
            table.insert(entries, { logical_id = id, term = term })
          end
        end
        if #entries == 0 then
          vim.notify("No shells open", vim.log.levels.INFO)
          return
        end
        table.sort(entries, function(a, b) return a.logical_id < b.logical_id end)

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local previewers = require("telescope.previewers")

        pickers.new({}, {
          prompt_title = "Shells",
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
                -- Limit previews for long-lived shells.
                lines = vim.api.nvim_buf_get_lines(entry.value.bufnr, -500, -1, false)
              end
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              set_preview_cursor(self.state.winid, lines)
            end,
          }),
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local entry = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if not entry then return end
              local term = entry.value
              if not is_live(term) then
                vim.notify("Shell no longer exists", vim.log.levels.INFO)
                return
              end
              focus_shell(entry.logical_id)
            end)
            return true
          end,
        }):find()
      end

      local bind = function(modes, lhs, rhs)
        vim.keymap.set(modes, lhs, rhs, { silent = true })
      end

      bind({ "n", "i", "t" }, "<C-t><C-t>", toggle_shell)
      bind({ "n", "i", "t" }, "<C-t><Tab>", pick_shell)
      for i = 1, 9 do
        bind({ "n", "i", "t" }, "<C-t>" .. i, function() focus_shell(i) end)
      end
      bind({ "n", "i", "t" }, "<C-t>n", new_shell)
      bind("t", "<C-t>x", close_current)

    '';
  };
}
