{ pkgs, ... }:

{
  programs.nixvim.plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
    package = pkgs.vimPlugins.project-nvim.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        # Fix JSON decode crash when history file is empty or being written concurrently
        # Fix vim.notify called in fast event context (libuv callback)
        # https://github.com/DrKJeff16/project.nvim - upstream is abandoned
        (pkgs.writeText "project-nvim-fix.patch" ''
          --- a/lua/project/util/history.lua
          +++ b/lua/project/util/history.lua
          @@ -401,8 +401,11 @@
             if fd and stat then
               local data = uv.fs_read(fd, stat.size)
               uv.fs_close(fd)
          -    if data then
          -      file_history = vim.json.decode(data) ---@type string[]
          +    if data and data ~= "" then
          +      local ok, decoded = pcall(vim.json.decode, data)
          +      if ok and decoded then
          +        file_history = decoded ---@type string[]
          +      end
               end
             end

          @@ -422,7 +425,9 @@
             if vim.tbl_isempty(tbl_out) then
               uv.fs_close(fd)
               Log.error(('(%s.write_history): No data available to write!'):format(MODSTR))
          -    vim.notify(('(%s.write_history): No data available to write!'):format(MODSTR), WARN)
          +    vim.schedule(function()
          +      vim.notify(('(%s.write_history): No data available to write!'):format(MODSTR), WARN)
          +    end)
               return
             end
        '')
      ];
    });
  };
}
