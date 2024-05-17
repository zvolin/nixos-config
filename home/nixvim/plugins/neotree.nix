{ ... }:

{
  programs.nixvim.plugins.neo-tree = {
    enable = true;

    window = {
      width = 35;
      height = 35;
    };

    popupBorderStyle = "rounded";

    # auto resize windows on tree open and close
    eventHandlers = {
      neo_tree_window_after_open = ''
        function(args) vim.cmd('wincmd =') end
      '';
      neo_tree_window_after_close = ''
        function(args) vim.cmd('wincmd =') end
      '';
    };
  };
}
