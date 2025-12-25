{ lib, config, ... }:

{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    # let terminal track current dir
    enableVteIntegration = true;

    history = {
      expireDuplicatesFirst = true;
      save = 50000;
      size = 20000;
    };

    oh-my-zsh.enable = true;

    # enable direnv for claude
    initContent = lib.mkOrder 500 ''
      if command -v direnv >/dev/null 2>&1; then
        if [ -n "$CLAUDECODE" ]; then
          eval "$(direnv hook zsh)"
          eval "$(DIRENV_LOG_FORMAT= direnv export zsh)"
        fi
      fi
    '';
  };
  # prompt
  programs.starship.enable = true;

  # env
  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
