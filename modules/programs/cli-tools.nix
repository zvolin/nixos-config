{...}: {
  flake.modules.nixos.cli-tools = {
    pkgs,
    lib,
    ...
  }: {
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
      (pkgs.writeShellScriptBin "reboot-macos" ''
        sudo ${lib.getExe pkgs.asahi-bless} --set-boot-macos --yes
        reboot
      '')
    ];
  };
}
