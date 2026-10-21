{ inputs, ... }:
let
  # p5 — the encrypted root region the Asahi installer created alongside the
  # Apple stub/EFI partitions (p1–p4). This is an INSTALL-TIME PLACEHOLDER: the
  # live p5 must be referenced by a stable identifier (by-partlabel or by-uuid,
  # NOT the /dev/nvme0n1p5 kernel name, which renumbers), confirmed against the
  # live disk at reinstall (docs/runbooks/mbp-install.md §1) before any disko
  # create. The token below is deliberately non-resolving so a create can never
  # run against an unconfirmed device; the disko VM test overrides it with /dev/vdX
  # regardless, so it does not block the agent-run gates.
  rootPartition = "/dev/disk/by-partlabel/REPLACE-WITH-P5-STABLE-ID-AT-INSTALL";

  # /, /nix, /persist, /var/log, /home all mount compressed; swap must not (below).
  compressedOpts = [
    "compress=zstd"
    "noatime"
  ];

  # The btrfs layout, authored once. The real aspect and the VM test share it and
  # differ only in how LUKS is unlocked and the swapfile size (see mkLayout and
  # mkBtrfsContent): the real aspect uses the full 24G swap matching the live
  # system, while the VM test uses 1G to fit the test disk.
  mkBtrfsContent = swapSize: {
    type = "btrfs";
    extraArgs = [ "-f" ];
    # Snapshot the fresh root subvolume to a readonly root-blank at format time.
    # impermanence.nix's initrd root-wipe restores root-blank every boot; on the
    # current host that snapshot was made by hand at install, so disko must recreate
    # it or impermanence breaks on a reinstall. Runs after the subvolumes are
    # created, with the fs unmounted but the LUKS mapper still open — mount the
    # mapper (hardcoded name, as impermanence.nix does), snapshot, unmount.
    postCreateHook = ''
      MNT=$(mktemp -d)
      mount /dev/mapper/nixos "$MNT" -o subvol=/
      trap 'umount "$MNT"; rm -rf "$MNT"' EXIT
      if ! btrfs subvolume show "$MNT/root-blank" >/dev/null 2>&1; then
        btrfs subvolume snapshot -r "$MNT/root" "$MNT/root-blank"
      fi
    '';
    subvolumes = {
      "root" = {
        mountpoint = "/";
        mountOptions = compressedOpts;
      };
      "nix" = {
        mountpoint = "/nix";
        mountOptions = compressedOpts;
      };
      "persist" = {
        mountpoint = "/persist";
        mountOptions = compressedOpts;
      };
      "log" = {
        mountpoint = "/var/log";
        mountOptions = compressedOpts;
      };
      "home" = {
        mountpoint = "/home";
        mountOptions = compressedOpts;
      };
      # swap: noatime ONLY — never compress. swapon fails on a compressed/COW btrfs
      # file, so the hand-written config omits compress here too. disko's btrfs swap
      # primitive runs `btrfs filesystem mkswapfile`, which marks the file NOCOW —
      # unlike a naive swapfile via swapDevices.
      "swap" = {
        mountpoint = "/swap";
        mountOptions = [ "noatime" ];
        swap.swapfile.size = swapSize;
      };
    };
  };

  # No GPT: the Asahi partition table, stub, and EFI are never named, so disko's
  # destructive create cannot select them (safe by absence — the same guarantee
  # nas-disko relies on for its 4×8 TB array). disko formats the existing p5 in
  # place as LUKS. luksAuth and swapSize differ between the real aspect and the VM
  # test: the real reinstall uses askPassword (interactive, no passwordFile ever
  # committed — Apple Silicon has no TPM/Secure-Enclave auto-unlock) and the full
  # 24G swap; the VM test uses a keyFile the harness prewrites at /tmp/secret.key
  # (makeDiskoTest does NOT set IN_DISKO_TEST, so askPassword would block on stdin)
  # and a 1G swap to fit the test disk.
  mkLayout = luksAuth: swapSize: {
    disk.main = {
      type = "disk";
      device = rootPartition;
      content = {
        type = "luks";
        name = "nixos";
        content = mkBtrfsContent swapSize;
      }
      // luksAuth;
    };
  };

  diskoDevices = mkLayout { askPassword = true; } "24G";
  testDiskoDevices = mkLayout { settings.keyFile = "/tmp/secret.key"; } "1G";
in
{
  # The named variant aspect. NOT imported by mbp-m2's live toplevel — importing it
  # would swap the boot-critical fileSystems. It is reached only by the throwaway
  # probe and, later, by the user's live-swap step (docs/runbooks/mbp-install.md).
  flake.modules.nixos.mbp-disko = {
    imports = [ inputs.self.modules.nixos.disko ];

    disko.devices = diskoDevices;

    # disko generates fileSystems.<mp> = { device; fsType; options; } but NOT
    # neededForBoot. The hand-written config marks these four needed-for-boot, so
    # re-assert it (this merges into disko's generated entries). /home and /swap are
    # deliberately not needed-for-boot, matching the hand-written config.
    fileSystems = {
      "/".neededForBoot = true;
      "/nix".neededForBoot = true;
      "/persist".neededForBoot = true;
      "/var/log".neededForBoot = true;
    };
  };

  # disko VM format test. aarch64-linux only — systems.nix also lists x86_64-linux,
  # which this repo never builds and where a cross-build would fail (same gate the
  # zellij checks use). testBoot = false: the layout has no /boot or bootloader
  # (partition-level; Asahi owns boot), so there is nothing to boot into — the test
  # only formats, mounts (at /mnt, the module-mode root), and asserts the
  # create-time invariants. It uses testDiskoDevices (keyFile unlock) so the format
  # step never blocks on an interactive passphrase.
  perSystem =
    { system, lib, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      checks = lib.optionalAttrs (system == "aarch64-linux") {
        mbp-disko-format = inputs.disko.lib.testLib.makeDiskoTest {
          inherit pkgs;
          name = "mbp-disko-format";
          disko-config = {
            disko.devices = testDiskoDevices;
          };
          testBoot = false;
          extraTestScript = ''
            # Under testBoot=false the fs is mounted at /mnt on the installer VM.
            # The readonly root-blank snapshot the postCreateHook must create:
            machine.succeed("btrfs subvolume list /mnt | grep -qs 'path root-blank$'")
            # The swapfile exists and activates — proves the NOCOW mkswapfile path:
            machine.succeed("test -e /mnt/swap/swapfile")
            machine.succeed("swapon /mnt/swap/swapfile && swapoff /mnt/swap/swapfile")
          '';
        };
      };
    };
}
