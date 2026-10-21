{ inputs, ... }:
{
  flake.modules.nixos.system-cli = {
    imports = with inputs.self.modules.nixos; [
      system-minimal
      cli-tools
      mosh
      openssh
      shell
      zellij
      nixvim
      stylix
    ];

    programs.ssh.askPassword = "";

    # SSH clients advertise their own TERM (xterm-kitty, xterm-ghostty, …). A
    # headless host that lacks the matching terminfo breaks ncurses/readline on
    # login — "can't find terminal definition", dead C-l, broken arrows. Ship
    # every terminal emulator's terminfo so any client resolves cleanly.
    environment.enableAllTerminfo = true;
  };
}
