{ ... }:

{
  flake.modules.nixos.boot-grub = { pkgs, ... }: {
    boot.loader.grub.enable = true;

    environment.systemPackages = [ pkgs.plymouth ];
    boot.extraModprobeConfig = ''
      options hid_apple iso_layout=0 swap_fn_leftctrl=1
    '';

    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };
  };
}
