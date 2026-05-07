{ inputs, ... }:
{
  flake.modules.nixos.shell = {
    programs.zsh.enable = true;
    home-manager.sharedModules = with inputs.self.modules.homeManager; [
      zsh
      bash
      fzf
      modern-cli
    ];
  };

  flake.modules.homeManager.zsh =
    {
      lib,
      config,
      ...
    }:
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
    };

  flake.modules.homeManager.bash =
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
    };

  flake.modules.homeManager.fzf =
    { ... }:
    {
      programs.fzf = {
        enable = true;

        defaultCommand = "fd --type f";
        defaultOptions = [
          "--layout=reverse"
          "--inline-info"
        ];
      };
    };

  flake.modules.homeManager.modern-cli =
    { pkgs, ... }:
    {
      programs.eza = {
        enable = true;
        enableZshIntegration = true;
        git = true;
        icons = "auto";
        extraOptions = [ "--group-directories-first" ];
      };

      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [ "--cmd cd" ];
      };

      programs.bat.enable = true;

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          side-by-side = true;
          navigate = true;
          line-numbers = true;
          wrap-max-lines = "unlimited";
          wrap-right-percent = 1;
        };
      };

      home.packages = with pkgs; [
        dust
        duf
        procs
        btop
        xh
        gping
        tealdeer
      ];

      programs.zsh.shellAliases = {
        cat = "bat -p --paging=never";
        grep = "rg --hidden --smart-case";
        find = "fd";
        du = "dust";
        df = "duf";
        ps = "procs";
        top = "btop";
        htop = "btop";
        tree = "eza --tree";
        ping = "gping";
      };
    };
}
