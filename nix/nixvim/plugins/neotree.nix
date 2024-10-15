{ ... }:

{
  programs.nixvim.plugins = {
    web-devicons.enable = true;
    neo-tree = {
      enable = true;

      window = {
        width = 35;
        height = 35;

        mappings = {
          # overwrite default open with window picker
          "<cr>" = "open_with_window_picker";
        };
      };

      popupBorderStyle = "rounded";

      # auto resize windows on tree open and close
      eventHandlers = {
        neo_tree_window_after_open = ''
          function(args)
            vim.cmd('wincmd =')
            reset_undotree_size()
          end
        '';
        neo_tree_window_after_close = ''
          function(args)
            vim.cmd('wincmd =')
            reset_undotree_size()
          end
        '';
      };
    };
  };
}
