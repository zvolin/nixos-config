# mbp-m2 install runbook

Bare-metal recovery / reinstall of the `mbp-m2` host (Apple Silicon MacBook Pro, aarch64) with disko-managed btrfs subvolumes on the encrypted root partition (`p5`), sops-managed login password, and Asahi-owned `/boot`. Run the steps in order.

## 0. Preamble

The Asahi installer owns the stub, EFI, and `/boot` partitions (`p1`–`p4`); disko only ever formats the encrypted root partition (`p5`). The layout created by `modules/hosts/mbp-m2/mbp-disko.nix` mirrors the hand-written `_host/hardware-configuration.nix`: partition-level LUKS (mapper `nixos`) + btrfs subvolumes (`root`, `nix`, `persist`, `log`, `home`, `swap`), compressed where appropriate. The readonly `root-blank` snapshot is created by `postCreateHook` at format time to support impermanence.

Prerequisites:
- The MacBook boots into a live environment (the Asahi installer ISO, or any rescue system with SSH/console access).
- This flake checked out, on the revision to deploy.
- Your SSH client holds the private key matching the authorized `zwolin@nixos` public key — the only post-boot entry into the box (the `openssh` aspect is key-only; physical console/keyboard is the fallback if the key path fails).
- Access to the private `zvolin/nixos-secrets` repo (to confirm `host_mbp` is enrolled).

### Cautions

- **The first LUKS passphrase prompt can be invisible.** On a no-splash Asahi boot it is easily swallowed by console/syslog output and looks like a hang. Start typing the passphrase blind (`***` appears as you type), or press Enter to reprint the prompt. Keep a USB keyboard to hand — early-boot input on Apple Silicon is known to be flaky, and the initrd wires a USB-keyboard fallback for when the internal one misses the prompt.
- **The 24 GB swapfile is a latent hibernation-corruption footgun.** The systemd-initrd root-wipe (impermanence) has no hibernation guard. That is harmless today — Asahi has no working hibernation and no `resumeDevice` is set — but the day either changes, resuming from an image the wipe has already discarded would corrupt the system. Do not enable hibernation (or set `resumeDevice`) on this host without first adding a hibernation guard to the wipe hook.
- **Back up the LUKS header and `/persist` before a destructive run.** Recovery on Apple Silicon is harder than on a standard PC — there is no normal UEFI, and the worst case is a DFU restore (a ~13 GB firmware re-download) followed by a full reinstall. A `cryptsetup luksHeaderBackup` of `p5` plus a copy of `/persist` kept off the machine turn a brick back into a restore.

## 1. Confirm the `p5` identifier (NEVER an Apple-owned partition)

The disko layout formats the device named in `rootPartition` in `modules/hosts/mbp-m2/mbp-disko.nix`. That placeholder is an install-time token that must be replaced with the live disk's stable identifier before any disko create. On the live MacBook:

```sh
lsblk -o NAME,SIZE,PARTLABEL,FSTYPE /dev/nvme0n1
ls -l /dev/disk/by-partlabel/ /dev/disk/by-uuid/
```

Pick the stable identifier for the existing encrypted root partition (`p5`). This will be a `/dev/disk/by-partlabel/<label>` or `/dev/disk/by-uuid/<uuid>` path, **never** a kernel name (`/dev/nvme0n1p5` renumbers) and **never** an Apple-owned partition (`p1`–`p4` are stub/EFI/`/boot` — disko would destroy them).

Set it as `rootPartition` in `modules/hosts/mbp-m2/mbp-disko.nix`, replacing the `REPLACE-WITH-P5-STABLE-ID-AT-INSTALL` placeholder:

```nix
rootPartition = "/dev/disk/by-partlabel/REPLACE-WITH-P5-STABLE-ID-AT-INSTALL";
```

Commit that one-line change (signed, on `main` or a branch):

```sh
git add modules/hosts/mbp-m2/mbp-disko.nix
git commit -m "fix(mbp-disko): set p5 root partition to <your-identifier>"
```

**Warning:** confirm the identifier is `p5` (the encrypted root) and never `p1`, `p2`, `p3`, or `p4` — those are Apple-owned and Asahi boot-critical. Formatting any of them breaks boot.

## 2. Confirm the swap sizing

The layout sizes swap at **24 GB**, mirroring the existing hand-written `_host/hardware-configuration.nix` (`swapDevices` → `size = 24 * 1024`). That is larger than the machine's 16 GB RAM because it copies the hand-written value verbatim, not because the size is derived from RAM. It is large enough to hold a hibernation image, but hibernation must not be enabled here without first guarding the impermanence wipe (see the swapfile caution in §0). Before a reinstall, confirm the size still suits the live machine's RAM:

```sh
free -h
```

If the live system has different RAM or you need a different swap size (e.g., for hibernation), adjust `swap.swapfile.size` in the `mkBtrfsContent` function in `modules/hosts/mbp-m2/mbp-disko.nix`:

```nix
swap.swapfile.size = "24G";  # adjust as needed
```

Commit that change if you modify it.

## 3. Key-birth ordering (sops host identity) — BEFORE reinstall

The login password is sops-encrypted and decrypted at activation by `sops-install-secrets` using the host key at `/persist/etc/ssh/ssh_host_ed25519_key`. If that key is missing at first boot, `hashedPasswordFile` is undecryptable → user creation fails → no login. Pre-plant the key at the exact path before `nixos-install`.

**Exact path matters.** The `openssh` aspect (via the shared `zwolin` import) hardcodes `hostKeys = [{ path = "/persist/etc/ssh/ssh_host_ed25519_key"; … }]`, and sops-nix derives its age identity from that same file. So the planted key must land at `/persist/etc/ssh/ssh_host_ed25519_key`. `/persist` is `neededForBoot` and survives the impermanence root wipe, making it the durable host-key location.

The `host_mbp` age recipient is already enrolled in `shared.yaml` at the locked `secrets` revision (committed in earlier work). Confirm the key on the live system matches the enrolled recipient before reinstalling:

```sh
sudo cat /persist/etc/ssh/ssh_host_ed25519_key.pub
nix run nixpkgs#ssh-to-age -- < /persist/etc/ssh/ssh_host_ed25519_key.pub
# Compare the age1… output to the enrolled host_mbp recipient in zvolin/nixos-secrets/.sops.yaml
```

If reinstalling on a machine that does not yet have a key at `/persist/etc/ssh/ssh_host_ed25519_key`, or if you are rotating the key, generate a new one and enroll it in `shared.yaml` before proceeding (see `common.md §Enroll a recipient`, substituting `host_mbp`).

## 4. The live `fileSystems` swap (boot-critical — `diff-closures` cannot catch a wrong mapping)

Replace the hand-written `modules/hosts/mbp-m2/_host/hardware-configuration.nix` import with `mbp-disko` in `modules/hosts/mbp-m2/configuration.nix`. Add a hand-declared `/boot` entry because `mbp-disko` deliberately excludes `/boot` (Asahi owns it):

```nix
# In modules/hosts/mbp-m2/configuration.nix:
imports = [
  # Remove or comment out:
  # ./_host/hardware-configuration.nix
  # Add:
  inputs.self.modules.nixos.mbp-disko
];

# Add the /boot entry separately (confirm /dev/nvme0n1p4 is the ESP on the live disk):
fileSystems."/boot" = {
  device = "/dev/nvme0n1p4";   # Asahi-owned EFI partition
  fsType = "vfat";
};
```

Commit this change:

```sh
git add modules/hosts/mbp-m2/configuration.nix
git commit -m "feat(mbp-m2): swap fileSystems to mbp-disko layout"
```

**Verification checklist (user-run AFTER switch, when booted into the new system):**

For each mountpoint (`/`, `/nix`, `/persist`, `/var/log`, `/home`, `/swap`), confirm the booted system's actual mount matches the disko-generated entry:

```sh
findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
btrfs subvolume list /
```

Expected:
- `/` → `/dev/mapper/nixos`, subvol `root`, options `compress=zstd,noatime`, `neededForBoot`
- `/nix` → `/dev/mapper/nixos`, subvol `nix`, options `compress=zstd,noatime`, `neededForBoot`
- `/persist` → `/dev/mapper/nixos`, subvol `persist`, options `compress=zstd,noatime`, `neededForBoot`
- `/var/log` → `/dev/mapper/nixos`, subvol `log`, options `compress=zstd,noatime`, `neededForBoot`
- `/home` → `/dev/mapper/nixos`, subvol `home`, options `compress=zstd,noatime` (NOT `neededForBoot`)
- `/swap` → `/dev/mapper/nixos`, subvol `swap`, options `noatime` only (NOT compressed), with `/swap/swapfile` active

Also confirm:
```sh
swapon --show   # /swap/swapfile should appear as active
```

If any mount, option, or subvolume name mismatches the disko-generated config, do not trust the layout — the boot-critical mappings are wrong.

## 5. Re-home every non-disk setting the hand-written file carries

disko generates the `fileSystems` and `swapDevices` entries, but does not regenerate the other settings the hand-written `_host/hardware-configuration.nix` carries. Re-home each non-disk setting into the host config or a hardware aspect:

- **`boot.initrd.availableKernelModules = [ "uas" ];`** → **re-home** into `modules/hosts/mbp-m2/configuration.nix`. This is needed for USB-attached storage at the passphrase prompt.

- **`networking.useDHCP = lib.mkDefault true;`** → **re-home** into `modules/hosts/mbp-m2/configuration.nix` (the shared `networking` aspect uses connman, which leaves `useDHCP` unset; this default is still safe).

**Note:** The stage-1 NVMe and Apple-keyboard drivers needed at the LUKS passphrase prompt come from the `asahi` import's `availableKernelModules`, not from host-level initrd config. No additional `boot.initrd.availableKernelModules` entries are required beyond `[ "uas" ]`.

After re-homing, `modules/hosts/mbp-m2/configuration.nix` should contain at minimum:

```nix
boot.initrd.availableKernelModules = [ "uas" ];
networking.useDHCP = lib.mkDefault true;
```

Commit the re-homed settings:

```sh
git add modules/hosts/mbp-m2/configuration.nix
git commit -m "feat(mbp-m2): re-home hardware-configuration non-disk settings"
```

## 6. Destructive bare-metal reinstall replay

Ordered checklist. Every step below is user-run on real hardware.

1. **Run the Asahi installer** (if not already done). This creates and owns the stub, EFI, and `/boot` partitions (`p1`–`p4`). The installer creates the encrypted root partition `p5` as well, but disko will reformat it in step 4.

2. **Clone this flake** onto the target or a build machine (can be the Mac itself, booted from an Asahi installer ISO or recovery environment):
   ```sh
   git clone <flake-url> /tmp/nixos-config
   cd /tmp/nixos-config
   ```

3. **(Only if preserving the existing host identity)** BEFORE the destructive create, copy the current key OFF `p5` to a safe scratch location that the reformat won't touch (e.g., installer ramdisk `/tmp`, or a USB stick):
   ```sh
   sudo cp /persist/etc/ssh/ssh_host_ed25519_key /tmp/mbp-hostkey
   ```
   If the old `/persist` is already gone or you are rotating the key, skip this and use the fresh-key path in step 5.

4. **Review, then run `disko`** on `p5` using the `mbp-disko` layout. Use the incremental `format,mount` mode — **not** `--mode disko`, which is the destructive `destroy,format,mount` full run — and review the generated script with `--dry-run` first (the disko maintainer's explicit advice). This still **reformats `p5`** and mounts the new layout at `/mnt` (so `/persist` is now at `/mnt/persist`, freshly empty).

   First, dry-run and read the generated script. Confirm it touches **only** your `p5` identifier and never the parent disk (`/dev/nvme0n1`) or the Apple partitions (`p1`–`p4`):
   ```sh
   sudo nix run github:nix-community/disko -- --mode format,mount --dry-run --flake .#mbp-m2
   ```
   If the script names any device other than your `p5` identifier, **STOP** — do not proceed. A dry-run that reaches the parent disk or an Apple partition is the one failure mode this review exists to catch. Then run it for real:
   ```sh
   sudo nix run github:nix-community/disko -- --mode format,mount --flake .#mbp-m2
   ```
   You will be prompted interactively for the LUKS passphrase (Apple Silicon has no TPM/Secure-Enclave auto-unlock, so the passphrase is entered at every boot; the first prompt may be invisible — see §0 cautions). The `root-blank` snapshot is created by the `postCreateHook` after the subvolumes are laid out.

5. **Plant the host key into the NEW `/persist`** at `/mnt/persist/etc/ssh/ssh_host_ed25519_key`:
   - **Preserve identity**: restore from the step-3 backup:
     ```sh
     sudo mkdir -p /mnt/persist/etc/ssh
     sudo cp /tmp/mbp-hostkey /mnt/persist/etc/ssh/ssh_host_ed25519_key
     sudo chmod 600 /mnt/persist/etc/ssh/ssh_host_ed25519_key
     ```
   - **OR fresh key**: generate and enroll:
     ```sh
     sudo mkdir -p /mnt/persist/etc/ssh
     sudo ssh-keygen -t ed25519 -N "" -f /mnt/persist/etc/ssh/ssh_host_ed25519_key -C root@mbp-m2
     sudo chmod 600 /mnt/persist/etc/ssh/ssh_host_ed25519_key
     ```
     Then enroll its age recipient in `shared.yaml` and re-lock the `secrets` input BEFORE `nixos-install` (see `common.md §Enroll a recipient` for the exact enroll+re-lock+decrypt-gate procedure, substituting `host_mbp`) — otherwise activation-time decrypt fails and login breaks.

6. **Install NixOS**:
   ```sh
   sudo nixos-install --flake .#mbp-m2
   ```
   This builds and installs the system closure into the disko-formatted layout at `/mnt`. The key you placed in `/mnt/persist` is preserved into the booted system.

7. **First boot**: Reboot into the installed system. At the LUKS prompt, enter the passphrase. After boot:
   - The `sops-install-secrets` activation script decrypts `hashedPasswordFile` via the planted host key at `/persist/etc/ssh/ssh_host_ed25519_key`.
   - The `zwolin` user is created with the decrypted password → login works.

8. **Verify login**:
   ```sh
   # Log in as zwolin (console or SSH if reachable over the network).
   sudo ls -l /run/secrets-for-users/zwolin/hashedPasswordFile
   ```
   A successful `sudo` (it prompts for the sops password) proves `hashedPasswordFile` decrypted and the user was created. If login or `sudo` fails, the host key / recipient enrollment (§3) is wrong — do not proceed.

## 7. Key material — archive and DR root

`mbp` keeps its GPG commit-signing identity (key `9DD9C8FD06750734`) and its
personal SSH key; no per-host server key lands here. Two things still matter for
durability:

1. **DR root to a password manager.** The personal `~/.ssh/id_ed25519` (private) and the
   GPG private key are the disaster-recovery root — back both up to your password
   manager (master-password recovery). `id_ed25519` is also the `ssh-to-age` source for the
   `user_zwolin` identity that opens the cold archive, so restoring it rebuilds the
   decrypt identity without a surviving laptop.
2. **Archive `mbp`'s host key** into `archive/keys.yaml` alongside the server keys
   (see the cold-archive sub-section).

### Cold archive of private key material

See `common.md §Cold-archive key material` for the full procedure.

## 8. Post-reinstall acceptance

After the first boot into the reinstalled system, confirm the closure matches expectations:

```sh
# On the booted mbp-m2:
nix store diff-closures /run/current-system /run/booted-system
# Or against a pinned reference before the reinstall
```

Compare the closure to a baseline built before the reinstall (if available) to confirm no unintended changes.
