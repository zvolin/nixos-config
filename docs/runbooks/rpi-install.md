# rpi install runbook

Headless install of the `rpi` host (Raspberry Pi 4B, aarch64) from an SD-image
built **natively on the Mac** (no disko, no kexec, no `nixos-anywhere`), with a
mount-and-plant host key and a sops-managed login password. Run the steps in order.

## 0. Prerequisites

- A microSD card and a way to flash it (another machine with a card reader).
- This flake checked out on the Mac, on the revision to deploy. The Mac is
  aarch64, so the `rpi` image and closure build natively — no emulation, no remote
  builder.
- Your SSH client holds the private key matching the authorized `zwolin@nixos`
  public key — the only post-boot entry into the box (the `openssh` aspect is
  key-only; physical console/keyboard is the fallback if the key path fails).
- Access to the private `zvolin/nixos-secrets` repo (to enroll `host_rpi`).

## 1. Key-birth: generate and enroll the `rpi` host key (BEFORE flashing)

The `rpi` uses the stock `/etc/ssh` host-key path (no impermanence). sops-nix
derives its age identity from `services.openssh.hostKeys`, so the planted key at
`/etc/ssh/ssh_host_ed25519_key` is also the sops decryption identity. Only the
ed25519 key is planted (it is the sops identity); the RSA key the aspect also
declares is auto-minted by sshd on first boot.

1. Generate the ed25519 host key on the Mac:
   ```sh
   ssh-keygen -t ed25519 -N "" -f host_rpi_ed25519_key -C root@rpi
   chmod 600 host_rpi_ed25519_key
   ```
2. Enroll the key as a recipient — see `common.md §Enroll a recipient` for the full
   enrollment mechanics (`ssh-to-age`, editing `.sops.yaml`, `sops updatekeys`, and
   re-locking the `secrets` input). The recipient name is `host_rpi`.

## 2. Confirm the static IP is free

See `common.md §Confirm the static IP is free`.

## 3. Build, flash, and plant — `nix run .#flash-rpi` (recommended)

The MacBook has no card reader, so the card lives in the Steam Deck and the Mac
drives it over SSH. One command on the Mac does the whole of §3–§5: builds the
image natively, copies it plus the host key to the Deck, flashes the card, and
plants the key — from the repo root (so `./host_rpi_ed25519_key` resolves):

```sh
nix run .#flash-rpi -- --dry-run   # build + detect the card, write nothing (first run)
nix run .#flash-rpi                 # the real thing; asks you to type 'yes' before dd
```

Safety: only *removable* disks are offered as targets, so the Deck's own SSD can
never be selected; the private key is copied to a Deck temp dir and wiped on exit
(even on failure). Insert the card in the Deck, `systemctl status sshd` on the
Deck if the Mac can't reach it, then run the command. Options: `--host`
(default `deck@steamdeck`), `--device /dev/sdX` (skip auto-detect), `--key`.

If the one-command path works, skip to §6. The manual steps below (§3m–§5) are the
fallback.

### 3m. Build the SD image natively on the Mac (manual)

```sh
nix build .#nixosConfigurations.rpi.config.system.build.sdImage
ls -l result/sd-image/           # a compressed .img.zst under result/sd-image/
```

## 4. Flash the image to the microSD (manual fallback — skip if you used §3)

```sh
# Identify the card device carefully (do NOT target the Mac's own disk):
lsblk
# Decompress and write (zstd-compressed image):
zstd -d result/sd-image/*.img.zst -o /tmp/rpi.img
sudo dd if=/tmp/rpi.img of=/dev/sdX bs=4M conv=fsync status=progress   # sdX = the card
sync
```

## 5. Mount-and-plant the host key (manual fallback — skip if you used §3)

```sh
# Mount the SD root partition (labeled NIXOS_SD):
sudo mkdir -p /mnt/rpi-root
sudo mount /dev/disk/by-label/NIXOS_SD /mnt/rpi-root
# Plant the ed25519 host key at the stock path (root, 600):
sudo mkdir -p /mnt/rpi-root/etc/ssh
sudo cp host_rpi_ed25519_key     /mnt/rpi-root/etc/ssh/ssh_host_ed25519_key
sudo cp host_rpi_ed25519_key.pub /mnt/rpi-root/etc/ssh/ssh_host_ed25519_key.pub
sudo chmod 600 /mnt/rpi-root/etc/ssh/ssh_host_ed25519_key
sudo chown 0:0 /mnt/rpi-root/etc/ssh/ssh_host_ed25519_key \
               /mnt/rpi-root/etc/ssh/ssh_host_ed25519_key.pub
sudo umount /mnt/rpi-root
```
Because the host key is present before first boot, the early
`setupSecretsForUsers` decrypt of `hashedPasswordFile` succeeds and `zwolin` is
created with its password — no first-boot login gap.

## 6. Boot and verify login

- Insert the card, power the Pi, wait for it to join the LAN.
- **Confirm the wired NIC name on the Pi's HDMI/serial console FIRST.** With
  `useDHCP = false` and the firewall on, the box has no network path in if the
  `10-lan` unit matched no interface — so the console (not SSH) is where you verify
  the match took. On the console:
  ```sh
  networkctl status        # or: ip -br link
  ```
  Confirm the onboard NIC appears (normally `end0`, matched by `en*`; some kernels
  name it `eth0`, matched by `eth*`) and that `10-lan` bound it with
  rpi's IP from `lan.json`. If the NIC enumerates as neither `en*` nor `eth*` (e.g.,
  `enp1s0` or `enu1u1` would NOT match), widen `matchConfig.Name` to
  `"en* eth* enu* enp*"` in `modules/hosts/rpi/configuration.nix`, rebuild
  (Mac-built closure), and reflash before expecting LAN reachability.
- SSH in as `zwolin` (key auth; only `:22` is open on the LAN):
  ```sh
  ssh rpi
  ```
- Confirm the sops password decrypted at activation:
  ```sh
  sudo ls -l /run/secrets-for-users/zwolin/hashedPasswordFile
  ```
  A successful `sudo` (it prompts for the sops password) proves `hashedPasswordFile`
  decrypted and the user was created. If login or `sudo` fails, the host key /
  recipient enrollment (§1) is wrong — do not proceed.

## 7. Day-2 rebuilds — Mac-built closure is the default

The canonical path is a Mac-built closure deployed to the Pi; it always works
(native aarch64 build on the Mac, and the Mac has `secrets` access). Leave
`--build-host` off so the build runs locally on the Mac — naming it (even as
`localhost`) makes `nixos-rebuild` SSH back into itself and die on
`Permission denied (publickey)`. The Pi has no root SSH (no root key,
`prohibit-password`), so deploy as `zwolin` and let `nixos-rebuild` elevate with
sudo. `--ask-sudo-password` prompts once on the Mac and feeds the sops login
password to sudo over the SSH — the Pi's wheel sudo requires a password (as on
every host here), so this is the standard deploy:

```sh
nixos-rebuild switch --flake .#rpi --target-host rpi --ask-sudo-password
```
(`--ask-sudo-password`, short form `-S`, is `--elevate=sudo --ask-elevate-password`;
the older `--use-remote-sudo` is deprecated.)

**Pi native-rebuild** (`nixos-rebuild switch` on the Pi) is a caveated fallback
only for trivial changes when `secrets` is unchanged: the weak Pi-4B is slow, may
OOM, and cannot fetch the private `secrets` repo. Any rebuild against a freshly
re-locked `secrets` rev must run on the Mac.

## 8. Per-host key material — mint, plant, trust, archive

`rpi` gets its own user key `zwolin@rpi` (ed25519, passphraseless). Unlike `nas`,
`rpi` builds on the Mac, so GitHub authentication is not build-critical — enroll
it for push/sign parity. The key still signs `rpi`'s commits and is its SSH client
identity into `nas`.

1. Mint on the Mac: `ssh-keygen -t ed25519 -N "" -C zwolin@rpi -f /tmp/zwolin-rpi`.
2. Author the pubkey map (private repo): add `zwolin@rpi` to `keys`, confirm the
   mesh edges (`authorized.nas` names `zwolin@rpi`). Commit + relock.
3. Plant at `/home/zwolin/.ssh/id_ed25519` (600, `zwolin`), post-boot or
   mount-and-plant.
4. Enroll on GitHub as authentication + signing key.
5. Archive the private key (see the cold-archive sub-section).
6. Verify: `ssh -T git@github.com` and an SSH-signed test commit.

### Cold archive of private key material

See `common.md §Cold-archive key material` for the full procedure.

## 9. Post-boot acceptance (reachability)

```sh
# From the rpi, reach the nas; from the Mac, reach the rpi:
ping -c3 nas                  # rpi → nas
```

## 10. UPS (NUT) — netclient monitoring `nas`

`rpi` is the NUT secondary (`netclient`): it runs only `upsmon`, monitoring
`eaton5e@nas` by LAN name, and halts **first** when the low-battery signal fires.
The `nut-client` aspect (`modules/services/nut-client.nix`) is already imported by
this host.

- **Physical:** `rpi` is on one of the UPS's two Schuko outlets, and the LAN
  switch must also ride the UPS — see the `nas` runbook §10.1 for why (without a
  protected switch, `rpi` loses contact with `nas` in a site-wide outage and never
  sees the low-battery signal). The UPS USB cable goes to `nas`, not here.
- **Secret:** `rpi` uses the same `nut/monitor-password` secret as `nas`. Once the
  `nas` runbook §10.2 has added it (nested under `nut.monitor-password`)
  and re-locked the `secrets` input, `rpi` needs no separate step — `host_rpi` is
  already a recipient of `shared.yaml`. The build will fail if the nested key is
  absent at the locked revision (sops-nix validates the key path at build time).
  Confirm it resolves before switching:
  ```sh
  nix eval --raw .#nixosConfigurations.rpi.config.sops.secrets.'"nut/monitor-password"'.path
  # → /run/secrets/nut/monitor-password
  ```
- **Verify at service start:** after the first switch that includes `nut-client`,
  check `upsmon` connected to `nas` and loaded its credential:
  ```sh
  systemctl status upsmon            # active, no credential-load failure
  upsc eaton5e@nas ups.status        # reaches nas's upsd over :3493
  ```
- Real coordinated-halt behavior is verified by the user-run pull-the-plug test in
  the `nas` runbook §10.4.
