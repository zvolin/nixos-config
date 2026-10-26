# nas ZFS pool creation runbook

One-time, by-id creation of the `tank` RAIDZ1 pool on `nas`, **encrypted at
creation**, plus the pool's dataset tree and properties. The agent is sandboxed, so
every step here is operator-run on the box (or on the build machine where noted).
Run the sections in order. On the **first** deploy that introduces ZFS to this
host, a one-time reboot is required between §0 and §1 so the `zfs` kernel module
loads (step 0.6); on a later deploy where ZFS already runs, do not reboot between
deploy and `zpool create`.

> **Scope of the auto-unlock.** The pool auto-unlocks at boot because the keyfile
> is sops-encrypted to the host key and sits on the **unencrypted ext4 SSD root**.
> Whole-box or SSD-root theft therefore yields the keyfile and unlocks the pool.
> The defended threat is a **stolen bare pool disk** (an RMA'd or pulled array
> member): the attacker has the ciphertext but not the keyfile and must
> brute-force the PBKDF2-stretched passphrase. It is not physical seizure of the
> running host. Accept this boundary before proceeding.

## 0. Author and escrow the passphrase (before creation)

`zpool create … -O keylocation=file:///run/secrets/zfs/tank-passphrase` reads that
file **at creation time**, so the secret must already be authored, locked, and
deployed. `nas`'s host key is already a `shared.yaml` recipient (it decrypts
`hashedPasswordFile`), so no new sops enrollment is needed.

1. **Generate a diceware passphrase** on a trusted machine (lowercase,
   hyphen-separated):
   ```sh
   nix run nixpkgs#diceware -- -n <count> -d -
   ```
   Keep the output in hand for the next two steps; do not echo it into shell
   history on the box.

2. **Write it into sops with no trailing newline** (the build machine, flake
   checkout):
   ```sh
   sops set "$SECRETS/shared.yaml" '["zfs"]["tank-passphrase"]' '"<passphrase>"'
   ```
   `sops set` stores the exact string with no trailing newline, so the keyfile
   bytes equal the passphrase and equal a later typed `-L prompt` line.

3. **Commit, push, relock, deploy:**
   ```sh
   # in the private secrets repo:
   git commit -am "feat(nas): add zfs/tank-passphrase" && git push
   # in this flake:
   nix flake lock --update-input secrets
   git commit -am "chore(flake): relock secrets for zfs/tank-passphrase"
   # on nas (build-on-target):
   sudo nixos-rebuild switch --flake /etc/nixos#nas
   ```
   This deploy lands `networking.hostId` and the keyfile at
   `/run/secrets/zfs/tank-passphrase`. A full `nixos-rebuild build` of `nas` only
   succeeds once the secret exists at the locked revision (`validateSopsFiles`),
   so §0 must complete before any full build.

   > **Expected here: `zfs-import-tank.service` fails and this switch reports a
   > non-zero exit.** The deploy activates `boot.zfs.extraPools = [ "tank" ]`
   > before the pool exists, so `zfs-import-tank.service` retries for ~60 s and
   > then fails; the switch surfaces that as a failed unit and a non-zero status.
   > This is expected until §1 creates the pool; the box is up and healthy
   > otherwise. Optionally clear the failed state with
   > `sudo systemctl reset-failed zfs-import-tank.service`. **Reboot rule is in step
   > 0.6:** on the first ZFS deploy you must reboot here so the `zfs` module loads
   > before §1; on later deploys ZFS already runs, so do not reboot before §1.

4. **Escrow the passphrase out-of-band, before creation:**
   - Store it in the password manager **and** on an offline paper copy.
   - Copy it **byte-for-byte, hyphens included**: a mismatched escrow fails the
     later reload-from-escrow recovery proof.
   - Give a second person custody of the escrowed copy (DR custody).

5. **Confirm the keyfile is present on the box:**
   ```sh
   sudo test -s /run/secrets/zfs/tank-passphrase && echo present
   ```
   Expected: `present`.

6. **Load the ZFS module — first ZFS deploy only (reboot once).** A `nixos-rebuild
   switch` cannot load a new kernel module into the already-running kernel, so the
   first deploy that introduces ZFS builds the `zfs` module into the new generation
   but leaves it absent from the booted kernel. `zpool create` in §1 would then fail
   with "The ZFS modules cannot be auto-loaded." On any later deploy ZFS is already
   loaded — skip this step. Check first:
   ```sh
   zpool status
   ```
   - `no pools available` → the module is loaded; go to §1.
   - a modprobe / "cannot be auto-loaded" error → first-time case. Confirm the module
     built into the new generation (the interactive shell aliases `find` to `fd`,
     which ignores `-name`, so escape it):
     ```sh
     \find -L /run/current-system/kernel-modules/lib/modules -name 'zfs.ko*'
     ```
     A `zfs.ko*` path means it built — reboot to load it. **Nothing** means ZFS is
     incompatible with this kernel (too new); stop and pin a ZFS-compatible kernel,
     a reboot will not help. To load the built module:
     ```sh
     sudo reboot
     # after it returns, confirm the module is live (not a module error):
     zpool status                                                    # "no pools available"
     sudo test -s /run/secrets/zfs/tank-passphrase && echo present   # keyfile re-placed at boot
     ```

## 1. Create the pool by-id, encrypted at creation

1. **Sanity-check the four array members** before creating:
   ```sh
   ls -l /dev/disk/by-id/ | grep -i wwn
   lsblk -o NAME,SIZE,SERIAL,MODEL
   ```
   Confirm four `WDC WD80EFPX` `wwn-*` disks (~8 TB each) enumerate and match the
   members pinned in `modules/hosts/nas/tank-disko.nix`. Verify the Kingston root SSD
   serial `50026B7283D9CB73` is **absent** from that member list. Confirm all four
   array disks are blank or intended-reclaimable. A member still carrying a bare ZFS
   label with no partition table is force-added without a refusal, so do **not** run
   against a disk whose contents you have not confirmed disposable. The device paths
   are fixed in Nix, so there is nothing to hand-type.

2. **Run the create app on nas as root** (after §0 deploy, so the keyfile exists),
   from a clean, committed tree. A dirty tree can rewrite `flake.lock`, the same rule
   as `nixos-rebuild`:
   ```sh
   sudo nix run /etc/nixos#create-nas-pool
   ```
   Root reads flakes from the system `/etc/nix/nix.conf`, so this builds the app
   natively on nas and runs it in one step. `zpool create`/`zfs create` need root; the
   app bundles its own `zfs`/`util-linux`. It runs disko's **create only** (no destroy,
   no mount) against the by-id members fixed in the spec: it builds the `raidz1` vdev
   with `ashift=12`, leaves `tank` root unencrypted, creates `tank/data` as the lone
   encryptionroot (reading `file:///run/secrets/zfs/tank-passphrase`), and lays down
   the dataset tree with the recorded per-dataset `recordsize`/`compression`/`logbias`.

   The generated script is a pure function of `modules/hosts/nas/tank-disko.nix` and
   the pinned disko rev, and is create-only by construction, so there is nothing
   run-specific to read in it before running. The per-run safety check is §1.1
   (confirming the four right disks), not the script contents; the script is re-verified
   when disko is bumped, not on every run.

3. **Check the exit code, not the log.** `disko-format` runs under `set -x`, which
   floods stderr with xtrace, so the exit code is the reliable signal. Exit 0 means
   the pool and datasets were created (or a benign idempotent re-run, when `tank`
   already imports). A **non-zero** exit means a member was rejected (a partition
   table or a foreign, non-ZFS filesystem) or the create otherwise failed. **STOP
   and investigate; nothing was built.** A `skipping creating zpool …` line on stderr
   is a secondary hint. A re-run is idempotent: it skips the already-imported `tank`
   and creates only the missing datasets. To recover from a mid-tree abort, fix the
   cause and re-run; no `zpool destroy` is needed. §1.4 then independently confirms
   the real pool.

4. **Verify encryption inheritance** before trusting the pool:
   ```sh
   sudo zfs get -r encryption,encryptionroot,keystatus tank
   ```
   Expected: `tank` shows `encryption=off`; every `tank/data*` dataset shows
   `encryption=aes-256-gcm`, `encryptionroot=tank/data`, `keystatus=available`.

5. **Export, then re-import by-id** to prove the by-id import path the
   declarative config relies on:
   ```sh
   sudo zpool export tank
   sudo zpool import -d /dev/disk/by-id tank
   sudo zfs load-key tank/data   # prompts or reads the keyfile
   sudo zfs mount -a
   ```

## 2. Confirm the declarative path survives a reboot

The reboot is the acceptance gate for unattended operation: it confirms
`zfs-import-tank.service` imports by-id, `zfs-load-key-tank.service` loads the key
after `sops-install-secrets`, and `zfs mount -a` mounts the tree, with no manual
steps.

```sh
sudo reboot
# after it comes back:
systemctl status zfs-import-tank.service zfs-load-key-tank.service zfs-mount.service
zfs get -r keystatus,mounted tank
systemctl --failed
```
Expected: both units `active` (the oneshot `exited`/`active`); every `tank/data*`
dataset `keystatus=available` and `mounted=yes`; `systemctl --failed` lists no ZFS
units.

> **Check `zfs-mount.service` on its own.** The stock mount service runs
> `zfs mount -a` early in boot, before `zfs-load-key-tank` has loaded the
> `tank/data` key. Current OpenZFS skips datasets whose key is unavailable and
> exits 0, so the unit stays green and `zfs-load-key-tank` mounts the tree a
> moment later. If instead it shows `failed`, that early run is erroring on the
> locked datasets — the pool is still fully mounted (the dedicated unit owns
> that), so drop the redundant stock unit: add `lib` to the module arguments in
> `modules/hosts/nas/zfs-pool.nix` and set
> `systemd.services.zfs-mount.enable = lib.mkForce false;`, then redeploy.

## 3. Extending the dataset tree later (idempotent re-run)

`create-nas-pool` is safe to re-run. It imports-or-skips the existing `tank` and
touches datasets only through `zfs create`/`zfs set` — no `destroy`, `wipefs`, or
`mkfs` is ever emitted — so a re-run cannot lose data. To add a dataset once the
pool is live:

1. Add it to `modules/hosts/nas/tank-disko.nix` and **land it in the deployed
   flake first.** The re-run executes whatever `/etc/nixos` resolves to; a change
   left only in a worktree is not seen. Commit and deploy (or merge) before the
   re-run.
2. Re-run on nas: `sudo nix run /etc/nixos#create-nas-pool`. Only missing datasets
   are created; the imported pool and existing datasets are skipped for creation.
3. **Mount the new dataset.** The create app makes datasets unmounted
   (`zfs create -u`), so run `sudo zfs mount tank/data/<new>` or reboot. New
   `tank/data*` children inherit encryption from `tank/data`, and the key is
   already loaded on a running box, so no passphrase is needed.

Two caveats:

- **A re-run reconciles existing datasets to the spec.** Each run re-applies the
  managed properties with `zfs set` on every existing dataset, so a property
  changed by hand on the box is reverted to its spec value. Change properties in
  `tank-disko.nix`, not with a live `zfs set`.
- **Downloads and import staging stay directories inside `tank/data/media`**, never
  a separate dataset. *arr atomic-moves and hardlinks work only within a single
  dataset; a split turns every import into a full copy.

## Operator checklist (run top to bottom)

- [ ] §0.1–0.3: passphrase generated, written to sops with no trailing
      newline, pushed, relocked, and `nas` deployed (`hostId` + keyfile landed).
- [ ] §0.4: passphrase escrowed (vault + offline paper, byte-for-byte,
      second-person custody) **before** any `zpool create`.
- [ ] §0.5: `/run/secrets/zfs/tank-passphrase` present on the box.
- [ ] §0.6: `zpool status` returns cleanly — on the first ZFS deploy, reboot once
      to load the `zfs` module before §1.
- [ ] Full `nixos-rebuild build --flake /etc/nixos#nas` succeeds on the box
      (gated on the secret; proves the aspect builds end-to-end).
- [ ] §1.1: four `wwn-*` ~8 TB `WD80EFPX` members sanity-checked against
      `tank-disko.nix`; Kingston root SSD serial excluded; all four confirmed
      blank or intended-reclaimable.
- [ ] §1.2–1.3: `create-nas-pool` app run on nas (exit 0); any non-zero exit
      investigated — nothing built on failure.
- [ ] §1.4: `zfs get -r encryption,encryptionroot,keystatus tank` confirms
      inheritance from `tank/data`.
- [ ] §1.5: export then `import -d /dev/disk/by-id`, load-key, mount -a all
      clean.
- [ ] §2: reboot; both ZFS units active, `zfs-mount.service` not failed
      (mask it if it is), all datasets unlocked and mounted, no failed units.
