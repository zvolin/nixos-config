{ ... }:
{
  flake.modules.nixos.boot-grub =
    { pkgs, ... }:
    {
      boot.loader.grub.enable = true;
      # Bound how many generations keep a kernel+initrd in the (small FAT) ESP.
      # Without this, /boot fills over time and bootloader install fails with
      # ENOSPC. Each distinct kernel version costs ~90M in /boot/kernels.
      boot.loader.grub.configurationLimit = 10;

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
