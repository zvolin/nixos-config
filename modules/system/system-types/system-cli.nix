{ inputs, ... }:

{
  flake.modules.nixos.system-cli = {
    imports = with inputs.self.modules.nixos; [
      system-minimal
      cli-tools
      openssh
      shell
    ];

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    programs.wireshark.enable = true;
    programs.ssh.askPassword = "";
  };
}
