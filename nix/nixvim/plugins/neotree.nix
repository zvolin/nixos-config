{ ... }:

{
  programs.nixvim.plugins = {
    web-devicons.enable = true;
    neo-tree = {
      enable = true;

      settings = {
        filesystem = {
          follow_current_file = {
            enabled = true;
            leave_dirs_open = true;
          };
          use_libuv_file_watcher = true;
        };

        popup_border_style = "rounded";

        window = {
          width = 35;
          height = 35;

          mappings = {
            # overwrite default open with window picker
            "<cr>" = "open_with_window_picker";
          };
        };

        # auto resize windows on tree open and close
        event_handlers = {
          __unkeyed1 = {
            event = "neo_tree_window_after_open";
            handler.__raw = ''
              function(args)
                vim.cmd('wincmd =')
                reset_undotree_size()
              end
            '';
          };
          __unkeyed2 = {
            event = "neo_tree_window_after_close";
            handler.__raw = ''
              function(args)
                vim.cmd('wincmd =')
                reset_undotree_size()
              end
            '';
          };
        };
      };
    };
  };
}
