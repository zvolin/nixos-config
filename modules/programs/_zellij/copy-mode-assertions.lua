-- Headless assertions for copy-mode-overlay.lua. Sourced by the
-- zellij-copy-mode-overlay check AFTER the overlay, in the same nvim.
--
-- The cycle is the only real logic here. The rest is a smoke test for Lua
-- syntax errors and buffer-local-versus-global scoping mistakes, which are
-- silent and destructive given that every mapping quits the editor.

local failures = {}

local function check(ok, message)
  if not ok then
    table.insert(failures, message)
  end
end

local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
local ctrl_v = vim.api.nvim_replace_termcodes('<C-v>', true, false, true)

check(vim.bo.modifiable == false, 'buffer is modifiable')
check(vim.bo.readonly == true, 'buffer is not readonly')
check(vim.bo.bufhidden == 'wipe', 'bufhidden is not wipe, quitting may prompt')
check(vim.o.clipboard == 'unnamedplus', 'clipboard is not unnamedplus, y will not reach +')

local function is_buffer_local(mode, lhs)
  return vim.fn.maparg(lhs, mode, false, true).buffer == 1
end

check(is_buffer_local('x', 'y'), 'y is not mapped buffer-locally in visual mode')
check(is_buffer_local('x', 'v'), 'v is not mapped buffer-locally in visual mode')
for _, key in ipairs({ 'q', 'i', 'a', '<Esc>' }) do
  check(is_buffer_local('n', key), key .. ' is not mapped buffer-locally in normal mode')
end

-- Esc in visual mode must stay native: the v-cycle costs v-as-cancel, so Esc
-- is the only way back to normal mode without leaving the buffer.
check(
  next(vim.fn.maparg('<Esc>', 'x', false, true)) == nil,
  'Esc is mapped in visual mode, so cancelling a selection quits instead'
)

vim.api.nvim_feedkeys('v', 'x', false)
check(vim.fn.mode() == 'v', 'native v did not enter charwise visual, got ' .. vim.fn.mode())
vim.api.nvim_feedkeys('v', 'x', false)
check(vim.fn.mode() == 'V', 'cycle step 1 expected linewise, got ' .. vim.fn.mode())
vim.api.nvim_feedkeys('v', 'x', false)
check(vim.fn.mode() == ctrl_v, 'cycle step 2 expected blockwise, got ' .. vim.fn.mode())
vim.api.nvim_feedkeys('v', 'x', false)
check(vim.fn.mode() == 'v', 'cycle step 3 expected charwise, got ' .. vim.fn.mode())
vim.api.nvim_feedkeys(esc, 'x', false)
check(vim.fn.mode() == 'n', 'Esc did not drop to normal mode, got ' .. vim.fn.mode())

if #failures > 0 then
  io.stderr:write('copy-mode overlay assertions failed:\n  ' .. table.concat(failures, '\n  ') .. '\n')
  vim.cmd('cquit! 1')
end
vim.cmd('qa!')
