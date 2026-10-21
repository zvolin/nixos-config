{ inputs, ... }:
{
  # SD-root image for the Pi-4B, parallel to `nas-disko`. `sd-image-aarch64.nix`
  # owns partitioning (FAT firmware + ext4 NIXOS_SD root), root fileSystems,
  # first-boot auto-expand, and extlinux/U-Boot boot — so no disko or
  # hardware-configuration.nix. The raspberry-pi-4 profile adds Pi-4B firmware,
  # kernel, and console. Built natively on the aarch64 Mac.
  flake.modules.nixos.rpi-sdimage =
    { lib, modulesPath, ... }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.raspberry-pi-4
        (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
      ];

      # Without this the Pi hangs on a black screen after GPU firmware (rainbow
      # splash): the raspberry-pi-4 profile enables extlinux, but nixos-hardware
      # ships no bootloader unless uboot.enable is set, so config.txt has no
      # `kernel=` line and no u-boot.bin to chainload.
      hardware.raspberry-pi.firmware.uboot.enable = true;

      # sd-image enables hardware.enableAllHardware for installer portability, but
      # its mainline-kernel module list (dw-hdmi, arcmsr, ...) breaks the
      # raspberry-pi-4 profile's linux-rpi vendor kernel: "FATAL: Module dw-hdmi
      # not found". Drop the kitchen sink; essential modules come from
      # includeDefaultModules.
      hardware.enableAllHardware = lib.mkForce false;
    };
}
