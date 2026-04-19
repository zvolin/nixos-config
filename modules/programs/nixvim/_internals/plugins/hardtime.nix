{ ... }:

{
  programs.nixvim = {
    plugins.hardtime = {
      enable = true;
      settings = {
        # disabled by default - user enables when practicing
        enabled = false;
        # show hints for better motions
        hint = true;
        # show notifications when keys are blocked
        notification = true;
        # auto-dismiss notifications after 2 seconds
        callback.__raw = ''
          function(text)
            vim.notify(text, vim.log.levels.WARN, { title = "Hardtime", timeout = 2000 })
          end
        '';
        # don't be too aggressive - allow 3 repeated keys
        max_count = 3;
      };
    };

    # keybinding to toggle hardtime
    keymaps = [
      {
        key = "<leader>th";
        action = "<cmd>Hardtime toggle<cr>";
        options.desc = "Toggle Hardtime training";
      }
    ];
  };
}
