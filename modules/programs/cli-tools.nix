{ ... }:
{
  flake.modules.nixos.cli-tools =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        bat
        btop
        curl
        delta
        devenv
        dig
        docker-compose
        duf
        dust
        eza
        fd
        fzf
        git
        gnupg
        gping
        htop
        jq
        ncdu
        openssh
        procs
        python3
        ripgrep
        sd
        tealdeer
        tmux
        wget
        xh
        zoxide
      ];
    };
}
