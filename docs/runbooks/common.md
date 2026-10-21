# Common procedures

Shared bare-metal install procedures referenced by the host runbooks (`nas-install.md`, `rpi-install.md`, `mbp-install.md`).

## Enroll a recipient

Pre-install enrollment of a host's ed25519 key as an age recipient in `shared.yaml`, so sops-managed secrets decrypt at activation.

1. Generate the host key (if not already done). Path depends on whether the host has impermanence:
   ```sh
   # Non-impermanent hosts (nas, rpi): /etc/ssh/ssh_host_ed25519_key
   ssh-keygen -t ed25519 -N "" -f <path-to-key> -C root@<host>
   chmod 600 <path-to-key>
   
   # Impermanent hosts (mbp-m2): /persist/etc/ssh/ssh_host_ed25519_key
   sudo mkdir -p /persist/etc/ssh
   sudo ssh-keygen -t ed25519 -N "" -f /persist/etc/ssh/ssh_host_ed25519_key -C root@<host>
   sudo chmod 600 /persist/etc/ssh/ssh_host_ed25519_key
   ```

2. Derive its age recipient:
   ```sh
   nix run nixpkgs#ssh-to-age -- < <path-to-key>.pub
   ```

3. Enroll the recipient and re-encrypt. In the private `zvolin/nixos-secrets` repo, edit `.sops.yaml` BY HAND:
   - Add an anchor: `- &host_<host> age1…` (the recipient from step 2)
   - Add `*host_<host>` to `shared.yaml`'s `key_groups` `age: [...]` list

   Editing `.sops.yaml` only DECLARES the recipient; the next command re-wraps the ciphertext.

   Re-encrypt with `sops updatekeys`. `sops updatekeys` must first DECRYPT `shared.yaml`, so it needs an identity that is ALREADY a recipient — your personal key (`user_zwolin`). Two traps:
   
   (a) sops reads the key FILE directly (it does NOT use ssh-agent), so a passphrase-protected personal key must be unlocked — `-stdinpass` feeds the passphrase in on stdin.
   
   (b) the recipients are NATIVE age keys (`ssh-to-age` emits `age1…`), so decryption needs a native age identity via `SOPS_AGE_KEY_FILE`. Do NOT reach for `SOPS_AGE_SSH_PRIVATE_KEY_FILE`: that selects age's `ssh-ed25519` stanza path, which cannot unwrap native `age1…` stanzas and fails with "no identity matched any of the recipients" even when the key is correct.

   ```sh
   umask 077
   nix run nixpkgs#ssh-to-age -- -private-key -stdinpass -i ~/.ssh/id_ed25519 -o /tmp/zage.txt
   # FAIL FAST: a mistyped passphrase makes ssh-to-age exit 0 with an EMPTY /tmp/zage.txt.
   # sops then silently falls back to your passphrase-protected ~/.ssh/id_ed25519 and dies
   # with a misleading "could not read passphrase" — stop here instead of chasing that.
   test -s /tmp/zage.txt || { echo "ssh-to-age produced no key — wrong passphrase, retry"; false; }
   SOPS_AGE_KEY_FILE=/tmp/zage.txt sops updatekeys shared.yaml   # confirm it ADDS host_<host> → y
   rg 'recipient:' shared.yaml      # expect the new recipient
   rm -f /tmp/zage.txt              # delete the native age identity (secret-equivalent to your key)

   git commit -am "chore(secrets): re-encrypt shared.yaml to host_<host>"
   git push
   ```

4. Re-lock the `secrets` input in this flake:
   ```sh
   nix flake lock --update-input secrets
   ```

5. **Gate:** do not proceed to install until `host_<host>` is a recipient of `shared.yaml` at the *locked* `secrets` revision. Confirm with a real-identity decrypt dry-run before running the install.

### Adding a secret with `sops set`

sops-nix splits secret names on `/` into a nested key path, so a secret like `nut/monitor-password` must be a **nested mapping** in `shared.yaml`:

```yaml
nut:
  monitor-password: <value>
```

A flat `nut/monitor-password:` key does NOT work — the `/` is a nesting separator, not part of a literal key string.

Use the `sops set` command to write it — this creates the nested path and writes a plain scalar with no trailing newline:

```sh
sops set shared.yaml '["nut"]["monitor-password"]' '"<value>"'
```

**Why this matters:** the module injects the value verbatim, so a stray trailing newline means the stored value and the client's credential no longer match byte-for-byte, and authentication fails silently at runtime — a hard-to-diagnose failure.

**Troubleshooting note:** if your sops admin identity is a passphrase-protected SSH key, sops ≥3.11 skips it rather than prompting. In that case, provision using an unencrypted age identity (extract it once into `~/.config/sops/age/keys.txt`).

### Build-time key validation

sops-nix validates each declared secret's key path at BUILD time (via `validateSopsFiles`, on by default), so a full `nixos-rebuild build` or `switch` FAILS EARLY with:

```
sops-install-secrets: manifest is not valid: secret <name> in .../shared.yaml is not valid: the key '<first-segment>' cannot be found
```

if the nested key is absent. Add the secret (nested) to `shared.yaml` and re-lock the `secrets` input BEFORE building or switching, or the build fails.

Confirm it resolves before switching:

```sh
nix eval --raw .#nixosConfigurations.<host>.config.sops.secrets.'"<secret-name>"'.path
# → /run/secrets/<secret-name>
```

This proves the secret is declared, not that it decrypts — runtime verification comes at service start.

## Cold-archive key material

The private halves are cold-archived for disaster recovery: encrypted in the private repo to the `user_zwolin` recipient **only** (never `user + host`), never Nix-decrypted, opened by hand with `sops -d` at replant.

- **Archive contents** (`archive/keys.yaml`): the three host keys (`ssh_host_ed25519_key` for `nas`, `rpi`, `mbp`) and the two per-host user keys (`zwolin@nas`, `zwolin@rpi`). Five private keys total.

- **`.sops.yaml` rule** — prepend, *above* the unanchored catch-all `'[^/]+\.yaml$'` (which otherwise matches the archive tail `keys.yaml` and encrypts it to all four recipients, defeating the user-only requirement). sops uses the first matching rule:
  ```yaml
  creation_rules:
    - path_regex: ^archive/.*\.yaml$
      key_groups:
        - age: [*user_zwolin]
    # … existing shared.yaml and catch-all rules follow …
  ```

- **DR layering (no circularity).** The archive decrypts only via `user_zwolin`, which is the `ssh-to-age` conversion of the personal `~/.ssh/id_ed25519`. That one key is backed up to a password manager (recovered by master password), *outside* the archive. Recovery runs one direction: restore `id_ed25519` from the password manager → `ssh-to-age` → the `user_zwolin` identity → `sops -d archive/keys.yaml` → replant the host/per-host keys. The key that opens the archive is recovered independently of the keys inside it; nothing decrypts itself.

- **Password-manager DR set:** the personal `~/.ssh/id_ed25519` (private) and the laptop GPG private key. These two, plus this repo, reconstitute everything.

## Confirm the static IP is free

The static IP is provisional (the DHCP pool boundary is unverified). From a host on the LAN:

```sh
ping -c3 <host>   # must NOT answer (free)
```

If it answers, pick another address outside the pool and update the `hosts` map in `lan.json` (private secrets repo), then relock the `secrets` input — the host's `10-lan` unit reads its IP from there via `lanConfig`.
