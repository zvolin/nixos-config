{...}: {
  programs.nixvim.plugins = {
    ts-context-commentstring.enable = true;
    comment = {
      enable = true;
      settings = {
        padding = true;
        sticky = true;
        ignore = "^$";

        pre_hook =
          # lua
          "require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()";
      };
    };
  };
}
