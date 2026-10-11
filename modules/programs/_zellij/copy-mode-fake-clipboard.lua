-- Test-only clipboard provider. Sourced by the zellij-copy-mode-yank check
-- AFTER the overlay, replacing its OSC-52 provider with one that writes what it
-- receives to a file. OSC 52 emits escape sequences to a terminal, which a
-- headless check cannot observe; what this check is for is the step before
-- that, that `y` reaches a provider at all before the editor quits.
local target = assert(os.getenv('COPY_MODE_TEST_OUT'))

local function record(lines)
  local handle = assert(io.open(target, 'w'))
  handle:write(table.concat(lines, '\n'))
  handle:close()
end

vim.g.clipboard = {
  name = 'test',
  copy = { ['+'] = record, ['*'] = record },
  paste = { ['+'] = function() return {} end, ['*'] = function() return {} end },
}
