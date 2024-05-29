{ ... }:

{
  # utility functions for other modules
  programs.nixvim.extraConfigLua = ''
    -- get the filetype of a window with given handle
    -- return "" if window is invalid
    local function win_filetype(handle)
      if vim.api.nvim_win_is_valid(handle) then
        -- get filetype property of buffer
        local buf = vim.api.nvim_win_get_buf(handle)
        return vim.api.nvim_buf_get_option(buf, "filetype")
      end
      -- invalid window handle
      return ""
    end

    -- resize Undotree window to base width
    function reset_undotree_size()
      local wins = vim.api.nvim_list_wins()
      -- iterate over windows
      for _, handle in ipairs(wins) do
        if win_filetype(handle) == "undotree" then
          -- reset the width
          local base_width = vim.g.undotree_SplitWidth
          vim.api.nvim_win_set_width(handle, base_width)
        end
      end
    end
  '';
}
