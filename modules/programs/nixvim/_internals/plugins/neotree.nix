{...}: {
  programs.nixvim.plugins = {
    web-devicons.enable = true;
    neo-tree = {
      enable = true;

      settings = {
        commands = {
          copy_relative_path.__raw = ''
            function(state)
              local node = state.tree:get_node()
              if not node or not node.path then return end
              local path = vim.fn.fnamemodify(node.path, ":.")
              vim.fn.setreg("+", path)
              vim.notify("Copied: " .. path)
            end
          '';
          copy_absolute_path.__raw = ''
            function(state)
              local node = state.tree:get_node()
              if not node or not node.path then return end
              vim.fn.setreg("+", node.path)
              vim.notify("Copied: " .. node.path)
            end
          '';
        };

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
            "y" = "noop"; # disable default file-copy to allow yy prefix
            "yy" = "copy_relative_path";
            "Y" = "copy_absolute_path";
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
