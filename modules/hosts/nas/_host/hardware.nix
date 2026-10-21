{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # The ESP is 512M; cap stored generations so /boot can't fill and wedge the
  # bootloader.
  boot.loader.systemd-boot.configurationLimit = 10;

  # x86 SATA/NVMe/USB controllers needed in initrd to reach the SSD root.
  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "xhci_pci"
    "usbhid"
    "sd_mod"
    "uas"
  ];

  # Raptor Lake (i5-14500) ships microcode fixes for the voltage/stability
  # errata; pull them in since this box runs unattended.
  hardware.cpu.intel.updateMicrocode = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
