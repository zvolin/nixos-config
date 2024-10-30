{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # let terminal track current dir
    enableVteIntegration = true;

    history = {
      expireDuplicatesFirst = true;
      save = 50000;
      size = 20000;
    };

    oh-my-zsh.enable = true;
  };
  # prompt
  programs.starship.enable = true;

  # env
  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
