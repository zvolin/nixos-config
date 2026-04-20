{...}: {
  flake.modules.nixos.impermanence = {
    boot.initrd.systemd.services.root-wipe = {
      description = "Wipe root btrfs subvolume and restore blank snapshot";
      wantedBy = ["initrd.target"];
      requires = ["cryptsetup.target"];
      after = ["cryptsetup.target"];
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        mount -t btrfs /dev/mapper/nixos /mnt
        btrfs subvolume list /mnt |
        awk -F/ '{print NF-1 " " $0}' |
        awk '{print $1 " " $NF}' |
        sort -r |
        cut -d' ' -f 2 |
        grep '^root' | grep -v '^root-blank' |
        xargs -I {} btrfs subvolume delete /mnt/{}
        btrfs subvolume snapshot /mnt/root-blank /mnt/root
        umount /mnt
      '';
    };

    environment.etc = {
      "nixos".source = "/persist/etc/nixos";
      "machine-id".source = "/persist/etc/machine-id";
    };
  };
}
