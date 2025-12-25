{ ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    # let terminal track current dir
    enableVteIntegration = true;

    historyControl = [ "erasedups" ];
    historyFileSize = 50000;
    historySize = 20000;

    # enable direnv for claude
    bashrcExtra = ''
      if command -v direnv >/dev/null 2>&1; then
        if [ -n "$CLAUDECODE" ]; then
          eval "$(direnv hook bash)"
          eval "$(DIRENV_LOG_FORMAT= direnv export bash)"
        fi
      fi
    '';
  };
}
