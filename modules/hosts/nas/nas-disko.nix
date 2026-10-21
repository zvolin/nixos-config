{ inputs, ... }:
let
  # The 931.5 GB Kingston SNV3S1000G NVMe (serial 50026B7283D9CB73) — confirmed at
  # install by size + serial as the root SSD, NOT one of the four 7.3 TB WDC WD80EFPX
  # array members (see docs/runbooks/nas-install.md §1). A stable /dev/disk/by-id/*
  # path, never /dev/nvme0n1 or /dev/sdX, which can renumber across boots.
  rootDiskById = "/dev/disk/by-id/nvme-KINGSTON_SNV3S1000G_50026B7283D9CB73";
in
{
  # Whole-disk layout for `nas`: GPT on the by-id 1 TB SSD → ESP (/boot) + ext4
  # root (/). The 4×8 TB array is never named here, so disko's destroy mode
  # cannot select it (safe by absence). Imports the `disko` wrapper so disko's
  # NixOS module is in the closure and auto-generates `config.fileSystems` from
  # this layout — there is no hand-written hardware-configuration.nix.
  flake.modules.nixos.nas-disko = {
    imports = [ inputs.self.modules.nixos.disko ];

    disko.devices.disk.main = {
      type = "disk";
      device = rootDiskById;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
