local root = vim.fn.getcwd()
local config = assert(io.open(root .. "/modules/programs/nixvim/_internals/plugins/toggleterm.nix")):read("*a")
local lua = assert(config:match("extraConfigLua = ''([%s%S]-)'';%s*};%s*}%s*$"))

local function expect(actual, expected, message)
  if actual ~= expected then
    error((message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then error(name .. ": " .. err, 0) end
  print("ok - " .. name)
end

local harness = {
  current_tab = "file-tab", current_buffer = 1, tabs = { "file-tab" },
  valid_buffers = { [1] = true }, cursor_calls = {}, invalid_buffer_checks = 0,
}
local terms_by_buffer, keymaps, preview_callbacks = {}, {}, {}

local function term(id, bufnr)
  local value = {
    logical_id = id, bufnr = bufnr, display_name = "term-" .. id,
    spawn = function(self)
      self.bufnr = self.bufnr or (1000 + id)
      harness.valid_buffers[self.bufnr] = true
    end,
    shutdown = function() end,
  }
  terms_by_buffer[bufnr] = value
  harness.valid_buffers[bufnr] = true
  return value
end

package.preload["toggleterm.terminal"] = function()
  return {
    find = function(predicate)
      for _, candidate in pairs(terms_by_buffer) do
        if predicate(candidate) then return candidate end
      end
    end,
    Terminal = { new = function(_, opts) return term(0, opts.bufnr or 0) end },
  }
end

package.preload["telescope.pickers"] = function()
  return { new = function(_, options)
    table.insert(preview_callbacks, options.previewer.define_preview)
    return { find = function() end }
  end }
end
package.preload["telescope.finders"] = function() return { new_table = function(options) return options end } end
package.preload["telescope.config"] = function() return { values = { generic_sorter = function() return {} end } } end
package.preload["telescope.actions"] = function() return { select_default = { replace = function() end }, close = function() end } end
package.preload["telescope.actions.state"] = function() return { get_selected_entry = function() return nil end } end
package.preload["telescope.previewers"] = function() return { new_buffer_previewer = function(options) return options end } end

vim = {
  g = { toggleterm_harness = true }, o = {}, log = { levels = { INFO = 1 } },
  schedule = function(fn) fn() end,
  cmd = function(command)
    if command:match("^tabnew") then
      harness.current_tab = "term-tab"
      harness.tabs = { "file-tab", "term-tab" }
    end
  end,
  notify = function() end,
  keymap = { set = function(_, lhs, rhs) keymaps[lhs] = rhs end },
  fn = { strdisplaywidth = function(value) return #value end, getcwd = function() return root end },
  api = {
    nvim_get_current_buf = function() return harness.current_buffer end,
    nvim_set_current_buf = function(bufnr) harness.current_buffer = bufnr end,
    nvim_buf_is_valid = function(bufnr)
      if not harness.valid_buffers[bufnr] then harness.invalid_buffer_checks = harness.invalid_buffer_checks + 1 end
      return harness.valid_buffers[bufnr] == true
    end,
    nvim_get_current_tabpage = function() return harness.current_tab end,
    nvim_set_current_tabpage = function(tab) harness.current_tab = tab end,
    nvim_tabpage_is_valid = function(tab) return tab ~= nil end,
    nvim_list_tabpages = function() return harness.tabs end,
    nvim_set_hl = function() end,
    nvim_create_autocmd = function() end,
    nvim_win_is_valid = function(win) return win == 71 end,
    nvim_win_set_cursor = function(win, position) table.insert(harness.cursor_calls, { win, position }) end,
    nvim_buf_get_lines = function(bufnr) return harness.buffer_lines[bufnr] or {} end,
    nvim_buf_set_lines = function() end,
  },
}

assert(load(lua, "@toggleterm-harness"))()
local api = assert(_G.toggleterm_harness)
harness.ai_terms = api.state.ai_terms
harness.shell_terms = api.state.shell_terms
harness.term = term
harness.set_current_buffer = function(bufnr) harness.current_buffer = bufnr end
harness.delete_buffer = function(bufnr)
  harness.valid_buffers[bufnr] = nil
  terms_by_buffer[bufnr] = nil
end
harness.set_group = function(group, values, last)
  local target = group == "ai" and harness.ai_terms or harness.shell_terms
  for id in pairs(target) do target[id] = nil end
  for id, value in pairs(values) do target[id] = value end
  (group == "ai" and api.set_ai_last or api.set_shell_last)(last)
end

function harness.reset()
  terms_by_buffer, keymaps, preview_callbacks = {}, {}, {}
  harness.current_tab, harness.current_buffer = "file-tab", 1
  harness.tabs = { "file-tab" }
  harness.valid_buffers = { [1] = true }
  harness.cursor_calls = {}
  harness.buffer_lines = {}
  harness.invalid_buffer_checks = 0
  assert(load(lua, "@toggleterm-harness"))()
  api = assert(_G.toggleterm_harness)
  harness.ai_terms = api.state.ai_terms
  harness.shell_terms = api.state.shell_terms
end

function harness.add_ai(id, bufnr)
  harness.ai_terms[id] = term(id, bufnr)
  api.set_ai_last(id)
end

function harness.add_shell(id, bufnr)
  harness.shell_terms[id] = term(id, bufnr)
  api.set_shell_last(id)
end

function harness.enter_ai(id)
  harness.current_tab = "file-tab"
  keymaps["<C-a>" .. id]()
end

function harness.enter_shell(id)
  harness.current_tab = "file-tab"
  keymaps["<C-t>" .. id]()
end

test("current AI terminal overrides newer group default", function()
  local claude_1 = harness.term(1, 101)
  harness.set_current_buffer(101)
  harness.set_group("ai", { [1] = claude_1 }, 2)
  expect(api.resolve_toggle_target(harness.ai_terms, 2), 1)
end)

test("current shell terminal overrides newer group default", function()
  local shell_1 = harness.term(1, 201)
  harness.set_current_buffer(201)
  harness.set_group("shell", { [1] = shell_1 }, 2)
  expect(api.resolve_toggle_target(harness.shell_terms, 2), 1)
end)

test("outside requested group keeps its saved default", function()
  harness.set_current_buffer(201)
  expect(api.resolve_toggle_target(harness.ai_terms, 2), 2)
end)

test("stale managed record falls back without validating its buffer", function()
  local stale = harness.term(1, 999)
  harness.set_group("ai", { [1] = stale }, 2)
  harness.delete_buffer(999)
  harness.set_current_buffer(1)
  expect(api.resolve_toggle_target(harness.ai_terms, 2), 2)
  expect(harness.invalid_buffer_checks, 0)
end)

test("live terminal outside the managed group keeps its saved default", function()
  local stale = harness.term(1, 999)
  harness.set_group("ai", { [1] = stale }, 2)
  harness.set_current_buffer(998)
  harness.term(1, 998)
  expect(api.resolve_toggle_target(harness.ai_terms, 2), 2)
end)

test("preview cursor is skipped for no lines and ends on the final copied line", function()
  api.set_preview_cursor(71, {})
  expect(#harness.cursor_calls, 0)
  api.set_preview_cursor(71, { "one", "two", "three" })
  expect(#harness.cursor_calls, 1)
  expect(harness.cursor_calls[1][2][1], 3)
end)

test("AI mapping returns to the file tab then reopens claude-1", function()
  harness.reset()
  harness.add_ai(1, 101)
  harness.add_ai(2, 102)
  harness.enter_ai(1)
  keymaps["<C-a><C-a>"]()
  expect(harness.current_tab, "file-tab")
  keymaps["<C-a><C-a>"]()
  expect(harness.current_buffer, 101)
end)

test("shell mapping returns to the file tab then reopens shell-1", function()
  harness.reset()
  harness.add_shell(1, 201)
  harness.add_shell(2, 202)
  harness.enter_shell(1)
  keymaps["<C-t><C-t>"]()
  expect(harness.current_tab, "file-tab")
  keymaps["<C-t><C-t>"]()
  expect(harness.current_buffer, 201)
end)

test("switching shell to AI preserves the original source tab", function()
  harness.reset()
  harness.add_shell(1, 201)
  harness.add_ai(1, 101)
  harness.enter_shell(1)
  keymaps["<C-a><C-a>"]()
  expect(harness.current_buffer, 101)
  keymaps["<C-a><C-a>"]()
  expect(harness.current_tab, "file-tab")
end)

test("empty picker previews never place a cursor", function()
  harness.reset()
  harness.add_ai(1, 101)
  harness.add_shell(1, 201)
  keymaps["<C-a><Tab>"]()
  keymaps["<C-t><Tab>"]()
  expect(#preview_callbacks, 2)
  for _, preview in ipairs(preview_callbacks) do
    preview({ state = { bufnr = 301, winid = 71 } }, { value = harness.term(1, 101) })
    expect(#harness.cursor_calls, 0)
  end
end)
