# nas install runbook

Headless install of the `nas` host (i5-14500, x86_64) via `nixos-anywhere` with a
disko whole-disk layout and sops-managed login password. Run the steps in order.

## 0. Prerequisites

- The target boots a Linux environment reachable over SSH as `root@<ip>` (the
  NixOS installer ISO, or any rescue system with SSH).
- This flake checked out on the build machine, on the revision to deploy.
- `nixos-anywhere` is run on demand: `nix run github:nix-community/nixos-anywhere -- …`.
- Your SSH client holds the private key matching the authorized
  `zwolin@nixos` public key — that is the only post-boot entry into the installed
  box (the `openssh` aspect is key-only, Tailscale is out-of-scope for homelab
  hosts; physical console is the fallback if the key path fails).
- The `nas` host key here is generated fresh per install. A later effort will
  store per-host and personal keys in `nixos-secrets` for durable backup and a
  stable host identity across reinstalls; until then, a destroy-reinstall mints a
  new host key and re-enrolls its recipient.

## 1. Confirm the root disk by-id (NEVER an array member)

The 4×8 TB array is safe by absence (disko only ever touches the disk named in
`modules/hosts/nas/nas-disko.nix`). On the target:

```sh
ls -l /dev/disk/by-id/
lsblk -o NAME,SIZE,SERIAL,MODEL
```

Pick the by-id path whose **size is ~1 TB** and whose **serial** matches the SSD
(not an 8 TB array member). Set it as `rootDiskById` in
`modules/hosts/nas/nas-disko.nix`, replacing `REPLACE-WITH-1TB-SSD-AT-INSTALL`.
Commit that one-line change.

> Optional extra hardening (documented, not mandated): add an activation-time
> assertion that the root disk is ~1 TB before trusting the layout.

## 2. Key-birth ordering (sops host identity) — BEFORE install

A fresh disko install has no pre-existing host key, so `--copy-host-keys` is
useless; if the host key is absent at first boot, `hashedPasswordFile` is
undecryptable → user creation fails → no login. Pre-plant the key instead.

**Exact path matters.** The `openssh` aspect points `hostKeys` at
`${config.sshHostKeyDir}/ssh_host_ed25519_key`, and sops-nix derives its
age-decryption identity from that same file (the repo sets no explicit
`sops.age.sshKeyPaths`). `sshHostKeyDir` defaults to `/etc/ssh`; only impermanent
hosts override it to `/persist/etc/ssh`, and nas has no impermanence — so the
planted key must land at `/etc/ssh/ssh_host_ed25519_key`. The age recipient
enrolled in `.sops.yaml` must be `ssh-to-age` of *this exact key*.

1. Pre-generate the ed25519 host key, staged at the path `--extra-files` will mirror
   into the target root (`/tmp/nas-keys` + `/etc/ssh/…` → `/etc/ssh/…`):
   ```sh
   mkdir -p /tmp/nas-keys/etc/ssh
   ssh-keygen -t ed25519 -N "" -f /tmp/nas-keys/etc/ssh/ssh_host_ed25519_key
   chmod 600 /tmp/nas-keys/etc/ssh/ssh_host_ed25519_key
   ```
2. Enroll the key as a recipient — see `common.md §Enroll a recipient` for the full
   enrollment mechanics (`ssh-to-age`, editing `.sops.yaml`, `sops updatekeys`, and
   re-locking the `secrets` input). The recipient name is `host_nas`.

The staged `/tmp/nas-keys` tree is the `--extra-files` payload for step 4.

This config exercises the activation-time early-decrypt (`sops-install-secrets`)
path.

## 3. Confirm the static IP is free

See `common.md §Confirm the static IP is free`.

## 4. Install

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nas \
  --target-host root@<target-ip> \
  --build-on remote \
  --extra-files /tmp/nas-keys
```

`--build-on remote` (explicit, not `auto`): the x86 `nas` builds its own closure;
the aarch64 build machine does not cross-build or emulate.
`--extra-files /tmp/nas-keys` plants the pre-generated host key at
`/etc/ssh/ssh_host_ed25519_key` before first boot so early-decrypt can read
the sops secret (see §2 for why that exact path).

## 5. First boot + verify login

- The machine reboots into the installed system.
- SSH in as `zwolin` (key auth — your client holds the private key matching the
  authorized `zwolin@nixos` public key; only `:22` is open on the LAN):
  ```sh
  ssh nas
  ```
- Confirm `sops-install-secrets` decrypted the password at activation:
  ```sh
  sudo ls -l /run/secrets-for-users/zwolin/hashedPasswordFile
  ```
  A successful `sudo` here (it prompts for the sops password) also proves the
  `hashedPasswordFile` decrypted and the user was created. If login or `sudo`
  fails, the host key / recipient enrollment (§2) is wrong — do not proceed.

## 6. Rebuilds — native on the box, or Mac-driven

The first rebuild runs on the box (no prior generation to deploy from):

```sh
ssh nas
sudo nixos-rebuild switch --flake /etc/nixos#nas   # native x86 rebuild, no remote
```

Day-2 you can drive it from the Mac — config authoring stays there while the build
runs natively on nas. The aarch64 Mac cannot build x86_64, so `--build-host` points
at nas itself (not the Mac); the flake is still evaluated on the Mac, and only the
build and activation happen on nas:

```sh
nixos-rebuild switch --flake .#nas --target-host nas --build-host nas \
  --ask-sudo-password --no-reexec
```

`--no-reexec` is required for a cross-arch target: without it `nixos-rebuild` builds
`config.system.build.nixos-rebuild` from the nas config (x86_64) and execs into it,
which segfaults on the aarch64 Mac. `--ask-sudo-password` prompts on the Mac and
feeds the sops password to sudo over SSH (nas wheel sudo requires a password).

## 7. Seed the AI credentials (per-host, per-account, out of sops)

No impermanence → `~` survives reboots; the jails bind the credential dirs
read-write. On the first SSH login, run each OAuth flow once:

- `claude` login (primary account)
- `claude2` login (second account)
- `codex` login

Tokens persist on root. A destroy-reinstall clears them (they live on root), so a
fresh build re-runs these logins once.

## 8. Per-host key material — mint, plant, trust, archive

`nas` gets its own user key `zwolin@nas` (ed25519, passphraseless — the box signs
and pushes non-interactively; a passphrase would force a pinentry on every
signature). The laptop's master SSH/GPG keys never land here. This one key does
triple duty: SSH client into `rpi`, GitHub authentication (so on-target builds can
fetch the private `secrets` input over `ssh://git@github.com`), and SSH commit
signing.

1. **Mint on the Mac, passphraseless:**
   ```sh
   ssh-keygen -t ed25519 -N "" -C zwolin@nas -f /tmp/zwolin-nas
   ```
2. **Author the pubkey map** (private `zvolin/nixos-secrets` repo): add the
   `zwolin@nas` public line to `pubkeys.json` → `keys`, and the mesh edges
   (`authorized.nas`, `authorized.rpi`). Commit, then
   `nix flake lock --update-input secrets` in this flake.
3. **Plant the private key** on `nas` at `/home/zwolin/.ssh/id_ed25519` (mode 600,
   owned by `zwolin`). `nas` has no impermanence, so `/home` survives — plant it
   post-boot over the LAN, or stage it into the `--extra-files` tree alongside the
   host key:
   ```sh
   install -Dm600 /tmp/zwolin-nas /tmp/nas-keys/home/zwolin/.ssh/id_ed25519
   install -Dm644 /tmp/zwolin-nas.pub /tmp/nas-keys/home/zwolin/.ssh/id_ed25519.pub
   ```
4. **Enroll on GitHub twice** — as an *authentication* key (git read/write; this
   is build-critical for `nas`, which fetches `secrets` on-target) and as a
   *signing* key (so GitHub verifies the signatures).
5. **Archive the private key** into the cold store (see the archive sub-section
   below).
6. **Verify on the booted box:**
   ```sh
   ssh -T git@github.com            # -> "Hi zvolin! …", authentication works
   git -C /persist/etc/nixos commit --allow-empty -m 'sig probe'   # SSH-signs the commit
   ```

### Cold archive of private key material

See `common.md §Cold-archive key material` for the full procedure.

## 9. Post-boot acceptance (the real closure + reachability checks)

```sh
# On the booted nas, after the first native rebuild:
nix store diff-closures /run/current-system ./result   # or against a pinned ref
```

## 10. UPS (NUT) — cabling, switch precondition, and the monitor secret

`nas` is the NUT primary (`netserver`): it runs the `usbhid-ups` driver, `upsd`,
and the `upsmon` primary for the shared Eaton 5E900UD, and cuts UPS power last. The
`nut-server` aspect (`modules/services/nut-server.nix`) is already imported by this
host; these are the physical and secret steps that make it work on real hardware.

Do these **before the first `nixos-rebuild switch` that includes `nut-server`** —
the sops secret must exist at the locked `secrets` revision or the build fails.

### 10.1 Physical cabling and the switch-on-UPS precondition

- Plug `nas` and `rpi` into the UPS's two Schuko outlets.
- Connect the UPS USB cable to `nas` (the driver host).
- **The LAN switch must also ride the UPS** (put the power strip on one Schuko —
  the strip is on hand). NUT does not halt a netclient on lost comms, so if the
  switch dies in a site-wide outage, `rpi` never sees the low-battery signal and
  its graceful-halt route becomes a no-op. This is a hard precondition, not a
  nice-to-have.

### 10.2 Add the `nut/monitor-password` secret (user-run HITL)

The monitor password is one shared value. On `nas` it backs two `upsd` accounts —
`upsmon` (primary, nas's own monitor) and `upsmonsec` (secondary, the rpi
netclient) — rpi's own upsmon can't issue FSD, but a compromised Pi holds the shared
password and could auth as the primary — a deliberate tradeoff favoring one credential
value over strict isolation. `host_nas` and `host_rpi` are already recipients of
`shared.yaml` (they read `hashedPasswordFile` from it), so **no `.sops.yaml`
recipient change is needed** — only a new key and a re-lock. In the private
`zvolin/nixos-secrets` repo:

1. Add the `nut/monitor-password` value to `shared.yaml` and re-encrypt. See
   `common.md §Enroll a recipient` for the `sops set` nested-key mechanics and the
   no-trailing-newline trap. Use:
   ```sh
   sops set shared.yaml '["nut"]["monitor-password"]' '"<value>"'
   ```
   (Decrypt-then-updatekeys flow is automatic; the recipients are unchanged, so this
   adds a key under the existing age group.)

   **Why this matters here:** the module injects the value verbatim into `upsd.users`
   and reads the monitor password file literally, so a stray trailing newline means
   the stored value and the client's credential no longer match byte-for-byte, and
   `upsmon` auth-fails silently at runtime — a hard-to-diagnose failure the §10
   verification below is there to catch early.

2. Commit and push the secrets repo.
3. Back in this flake, re-lock that input and sign it:
   ```sh
   nix flake update secrets
   ```
4. **Gate (build-time validation):** see `common.md §Enroll a recipient` for
   sops-nix's build-time key validation. Confirm the secret resolves before switching:
   ```sh
   nix eval --raw .#nixosConfigurations.nas.config.sops.secrets.'"nut/monitor-password"'.path
   # → /run/secrets/nut/monitor-password
   ```
   This proves the secret is declared, not that it decrypts — see step 5.

5. **Gate (runtime, auth):** after the first switch that includes `nut-server`,
   confirm the credential actually decrypted and authenticates — this is the first
   place a wrong recipient or a trailing-newline mismatch shows up:
   ```sh
   systemctl status upsd upsmon          # active, no credential-load failure
   upsc eaton5e@localhost ups.status     # returns a status → upsmon auth succeeded
   ```

### 10.3 Verify the driver reports runtime (confirm the threshold arms)

The driver directive `override.battery.runtime.low = 600` only arms if the driver
reports `battery.runtime`. After cabling and the first switch, confirm:

```sh
upsc eaton5e battery.runtime   # on nas — expect a sane number of seconds
```

On this entry-level Eaton 5E the variable can be **absent**. If it is, the
600-second margin never arms and the halt falls back to the UPS hardware
low-charge threshold (a few minutes), silently defeating the margin. In that case
change the directive in `modules/services/nut-server.nix` to
`override.battery.charge.low` (a percentage) and re-deploy.

### 10.4 Real behavior is a user-run pull-the-plug test

Build acceptance only proves the config evaluates and the secret resolves. Confirm
the actual coordinated halt by pulling wall power with both hosts on battery and
watching `rpi` halt first, then `nas` halt and cut UPS power. The primary's wait
for the secondary to drop (HOSTSYNC, default 15 s) is best-effort — if `rpi` takes
longer, `nas` cuts power anyway, so the halt ordering is not a hard guarantee.
This is a post-deploy HITL check, not gated by the build.

This proves the hosts go *down* cleanly; proving they come *back* is §10.5.

### 10.5 Unattended recovery: BIOS auto-power-on + the UPS off-window

A clean shutdown is only half the job — after mains returns the hosts must power
back on by themselves. Two independent pieces make that work; both bit us during
bring-up.

**1. BIOS "Restore AC Power Loss" must be `Power On`.** On the ASUS ROG Strix
B760-I, set **Advanced → APM Configuration → Restore AC Power Loss → Power On**
(not `Last State`, not `Power Off`). `Last State` is a trap: during a coordinated
shutdown `nas` halts to S5 *before* the UPS cuts power, so the latched "last state"
is *off* and `nas` stays down on return. `Power On` boots whenever power is
applied, which is what unattended recovery needs. `rpi` has no equivalent setting —
a Pi boots whenever it has power.

- Enter firmware with **`Del` at POST**. Do **not** use
  `systemctl reboot --firmware-setup` on this board — it does not clear the
  `OsIndications` EFI flag, so the box re-enters setup on every boot (a loop whose
  only clean exits are a one-shot Boot Override to the OS disk, or Clear CMOS).
- **Re-verify this setting after any Clear CMOS / coin-cell pull** (e.g. after
  escaping the boot-loop above). A CMOS clear resets it to the board default
  (`Power Off`), silently undoing it — this is exactly how it regressed for us
  after it had already been set and tested.

**2. The UPS off-window must be long enough for `nas`'s PSU to register the loss.**
`usbhid-ups` measures both `offdelay` and `ondelay` from the kill-power command, so
a `shutdown.return` cycle leaves the output dark for `ondelay - offdelay` seconds.
At the 20/30 defaults that is only ~10 s — short enough that `nas`'s ATX PSU rides
through on its standby rail, the board never sees an AC loss, and `Power On` never
fires. `nut-server.nix` sets `offdelay = 15` / `ondelay = 40` (a ~25 s window) to
force a true power-off. A real outage already holds power off until mains returns,
so this only matters for the mains-present test and the rare case where grid power
returns within seconds of the cut.

killpower itself needs no extra config: NixOS wires `ups-killpower.service` (runs
`upsdrvctl shutdown` at `shutdown.target` when `/run/killpower` exists) automatically
whenever `upsmon` runs with a `POWERDOWNFLAG` (default `/run/killpower`) — true on
`nas`. `driver.flag.allow_killpower` is unrelated —
it only gates the runtime `driver.killpower` instant command, not the
`upsdrvctl shutdown` path.

**Recovery test (battery-based — the mains-present `fsd` does NOT prove this).**
Extends the §10.4 pull-the-plug test by keeping mains off long enough to be a real
outage, then restoring it:

```sh
#  1. pull the UPS's mains plug           → UPS on battery
#  2. sudo upsmon -c fsd                   → nas + rpi halt; killpower cuts output ~15 s later (offdelay)
#  3. leave mains UNPLUGGED for >= 30 s    → a real-outage-length off-window
#  4. plug mains back in                   → UPS re-powers the output
#  5. both hosts cold-boot on their own    → recovery confirmed
```

The mains-present `upsmon -c fsd` validates the shutdown + killpower path, but its
off-window is only `ondelay - offdelay`, so it holds only as long as those delays
are set right. Prefer the battery-based test above: its off-window is the full
outage, independent of the delay values, so it stays faithful even if the
`ondelay`/`offdelay` math is ever wrong for your unit. A green NIC link LED on an
otherwise-unreachable host means it has standby power but is parked in S5 — it did
*not* auto-boot.

### 10.6 Silence the UPS beeper (one-time)

The on-battery beep is firmware-fixed (cadence is not configurable; NUT only
exposes enable/disable/mute, none of which change it) and merely annoying in a
homelab. Disable it once — the
setting persists in UPS firmware across reboots, so this is imperative, not
declarative. The primary `upsmon` account carries an `instcmds = [ "beeper.disable" ]`
grant (in `nut-server.nix`) for exactly this; without it `upscmd` returns
`access denied`, because `upsmon = "primary"` grants monitoring/FSD actions but not
instant commands.

```sh
upscmd -l eaton5e@localhost                 # confirm the command name on your unit
upscmd -u upsmon -p "$(sudo cat /run/secrets/nut/monitor-password)" \
  eaton5e@localhost beeper.disable
upsc eaton5e@localhost ups.beeper.status    # -> disabled
```
