-- Copy mode for zellij scrollback dumps.
--
-- Sourced only by the copy branch of ./copy-mode.nix's wrapper, which is never
-- on PATH. An ordinary nvim never reads this file, and that is what makes it
-- safe for every mapping here to quit the editor.
--
-- Everything is buffer-local except the three options marked GLOBAL below.
-- Those are acceptable only because the process this runs in exists solely for
-- copy mode; none of them may migrate into the shared config as a side effect.

local buf = vim.api.nvim_get_current_buf()
local opts = { buffer = buf, silent = true }

-- A dump is a read-only snapshot. bufhidden=wipe so nothing prompts on quit.
vim.bo[buf].readonly = true
vim.bo[buf].modifiable = false
vim.bo[buf].bufhidden = 'wipe'

-- GLOBAL. Routes bare `y` to the `+` register. The real config sets it in
-- nixvim/_internals/options.nix, but copy mode's job is getting text onto the
-- client's clipboard, so it does not borrow that from a file ticket [52] is
-- expected to change.
vim.o.clipboard = 'unnamedplus'

-- GLOBAL. Neovim has no buffer-local clipboard provider. `unnamedplus`
-- disables neovim's own OSC-52 auto-selection (ticket [50]), so the provider
-- has to be named explicitly. Zellij intercepts the escape and re-emits it
-- through its own clipboard_provider, which reaches the phone. Delete this
-- block once ticket [52] gives the real config a provider.
local osc52 = require('vim.ui.clipboard.osc52')
vim.g.clipboard = {
  name = 'OSC 52',
  copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
  -- kitty and Termux both refuse OSC-52 reads, and zellij's own
  -- paste-from-clipboard arm is an unimplemented TBD, so paste cannot work.
  paste = { ['+'] = function() return {} end, ['*'] = function() return {} end },
}

-- GLOBAL. Touch-drag selection on the phone.
vim.o.mouse = 'a'

-- `v` cycles charwise -> linewise -> blockwise; the phone taps v, vv, vvv
-- instead of needing Shift or Ctrl. It costs v-as-cancel inside visual mode,
-- so Esc is left native there.
--
-- The function returns the string '<C-v>'. Because vim.keymap.set defaults
-- replace_keycodes to true for expr mappings, that string is run through
-- nvim_replace_termcodes and becomes the control byte (0x16 / blockwise-visual).
-- The hazard is returning a pre-converted control char instead of the '<C-v>' string.
vim.keymap.set('x', 'v', function()
  local mode = vim.fn.mode()
  if mode == 'v' then
    return 'V'
  elseif mode == 'V' then
    return '<C-v>'
  end
  return 'v'
end, vim.tbl_extend('force', opts, { expr = true }))

-- Yank, then quit. The quit MUST be scheduled: neovim defers the clipboard
-- provider's copy call to the next event-loop turn, so quitting inline throws
-- the yank away silently. vim.schedule suffices because the deferred copy was
-- queued first and the queue is FIFO.
vim.keymap.set('x', 'y', function()
  vim.cmd('normal! y')
  vim.schedule(function()
    vim.cmd('qa!')
  end)
end, opts)

-- Every bail-out key. `i` and `a` are here because reaching for insert in a
-- read-only snapshot means you are done looking.
for _, key in ipairs({ 'q', 'i', 'a', '<Esc>' }) do
  vim.keymap.set('n', key, '<Cmd>qa!<CR>', opts)
end
