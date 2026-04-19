{ ... }:

{
  flake.modules.nixos.cli-tools = { pkgs, lib, ... }: {
    environment.systemPackages = with pkgs; [
      bat
      curl
      devenv
      dig
      docker-compose
      fd
      fzf
      git
      htop
      jq
      ncdu
      neovim
      openssh
      plymouth
      python3
      ripgrep
      sd
      tmux
      vim
      wget
      (pkgs.writeShellScriptBin "reboot-macos" ''
        sudo ${lib.getExe pkgs.asahi-bless} --set-boot-macos --yes
        reboot
      '')
    ];
  };
}
