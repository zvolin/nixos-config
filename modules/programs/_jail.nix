# Shared bwrap jail builder for the AI CLIs (Claude, Codex). Underscore-prefixed
# so import-tree skips auto-discovery; both clients `import ../../_jail.nix`
# directly. Single source of truth for containment and per-client autonomy.
{ pkgs, lib }:
let
  bwrap = lib.getExe pkgs.bubblewrap;

  # --- env passthrough allowlist (after --clearenv we re-inject via --setenv) ---
  coreEnv = [
    "HOME"
    "EDITOR"
    "VISUAL"
    "XDG_RUNTIME_DIR"
    "WAYLAND_DISPLAY"
    "DISPLAY"
    "TERM"
    "LANG"
    "LC_ALL"
    "SSH_AUTH_SOCK"
    "DBUS_SESSION_BUS_ADDRESS"
    "GPG_TTY"
  ];

  tokenEnv = [
    "GH_TOKEN"
  ];

  nixDevshellEnv = [
    "CC"
    "CXX"
    "AR"
    "AS"
    "LD"
    "NM"
    "RANLIB"
    "STRIP"
    "OBJDUMP"
    "OBJCOPY"
    "SIZE"
    "STRINGS"
    "RUST_SRC_PATH"
    "CARGO_NET_GIT_FETCH_WITH_CLI"
    "LIBCLANG_PATH"
    "BINDGEN_EXTRA_CLANG_ARGS"
    "NIX_CC"
    "NIX_CC_FOR_TARGET"
    "NIX_BINTOOLS"
    "NIX_BINTOOLS_FOR_TARGET"
    "NIX_CFLAGS_COMPILE"
    "NIX_CFLAGS_COMPILE_FOR_TARGET"
    "NIX_LDFLAGS"
    "NIX_LDFLAGS_FOR_TARGET"
    "NIX_HARDENING_ENABLE"
    "NIX_ENFORCE_NO_NATIVE"
    "NIX_DONT_SET_RPATH"
    "NIX_DONT_SET_RPATH_FOR_BUILD"
    "NIX_NO_SELF_RPATH"
    "NIX_IGNORE_LD_THROUGH_GCC"
    "NIX_STORE"
    "NIX_BUILD_CORES"
    "PKG_CONFIG_PATH_FOR_TARGET"
    "IN_NIX_SHELL"
    "SOURCE_DATE_EPOCH"
    "HOST_PATH"
    "PATH_LOCALE"
    "CONFIG_SHELL"
    "ZERO_AR_DATE"
  ];

  archEnv = [
    "NIX_CC_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_CC_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
  ];

  baseEnv = coreEnv ++ tokenEnv ++ nixDevshellEnv ++ archEnv;

  # --- per-client policy: single source of truth ---
  clients = {
    claude = {
      rawBinary = lib.getExe pkgs.claude-code;
      unleashFlags = [ "--dangerously-skip-permissions" ];
      markerEnv = "CLAUDE_SANDBOX";
    };
    codex = {
      rawBinary = lib.getExe pkgs.codex;
      unleashFlags = [ "--dangerously-bypass-approvals-and-sandbox" ];
      markerEnv = "CODEX_SANDBOX";
    };
  };

  mkJail =
    {
      name,
      policy,
      extraEnv ? [ ],
      pathPrefix ? [ ], # list of packages; their /bin dirs are prepended to PATH
      preCreateDirs ? [ ],
      preCreateFiles ? [ ], # files touched (create-if-absent) before their binds
    }:
    let
      envAllowlist = baseEnv ++ [ policy.markerEnv ] ++ extraEnv;
      unleashStr = lib.escapeShellArgs policy.unleashFlags;
      pathPrefixStr = lib.optionalString (pathPrefix != [ ]) "${lib.makeBinPath pathPrefix}:";
      pathSetenv = ''"${pathPrefixStr}''${PATH}"'';
      preCreate = lib.concatStringsSep " " (
        [
          ''"$HOME/.cargo"''
          ''"$HOME/.cache/gh"''
        ]
        ++ map (d: ''"$HOME/${d}"'') preCreateDirs
      );
      preCreateTouch = lib.concatMapStringsSep "\n" (
        f: ''touch "$HOME/${f}" 2>/dev/null || true''
      ) preCreateFiles;
      bindsRW = lib.concatMapStringsSep "\n    " (d: ''bind_rw "$HOME/${d}"'') (
        preCreateDirs ++ preCreateFiles
      );
      wrapper = pkgs.writeShellScriptBin name ''
        bind_ro() { [[ -e "$1" ]] && args+=(--ro-bind "$1" "$1"); }
        bind_rw() { [[ -e "$1" ]] && args+=(--bind    "$1" "$1"); }
        pass_env() { [[ -n "''${!1:-}" ]] && args+=(--setenv "$1" "''${!1}"); }

        # Preload the GH token so the sandboxed `gh` CLI has credentials — it
        # cannot reach the host keyring from inside the jail.
        if [ -z "''${GH_TOKEN:-}" ]; then
          GH_TOKEN=$(${lib.getExe pkgs.gh} auth token 2>/dev/null) || true
        fi
        export GH_TOKEN

        # bind_rw/bind_ro skip missing sources, so dirs/files must be
        # pre-created before their binds, or a first-time write lands in
        # the tmpfs $HOME and dies on exit.
        mkdir -p ${preCreate}
        ${preCreateTouch}

        export ${policy.markerEnv}=1

        args=(
          --unshare-ipc --unshare-pid --unshare-uts --unshare-cgroup
          --die-with-parent --clearenv
          --dev /dev --proc /proc --tmpfs /tmp
          --ro-bind /nix /nix
          --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket
          --ro-bind /etc/resolv.conf /etc/resolv.conf
          --ro-bind /etc/ssl         /etc/ssl
          --ro-bind /etc/hosts       /etc/hosts
          --ro-bind /etc/passwd      /etc/passwd
          --ro-bind /etc/group       /etc/group
          --ro-bind /etc/nix         /etc/nix
          --ro-bind-try /etc/static         /etc/static
          --ro-bind-try /etc/profiles       /etc/profiles
          --ro-bind-try /run/current-system /run/current-system
          --symlink ${pkgs.bash}/bin/bash     /bin/sh
          --symlink ${pkgs.coreutils}/bin/env /usr/bin/env
          --tmpfs "$HOME"
        )

        # Resolve symlinks so /etc/nixos and /persist/etc/nixos bind the same path.
        pwd_abs=$(realpath "$PWD")
        # When launched from $HOME, binding $pwd_abs over the tmpfs $HOME re-exposes
        # the real home's store symlinks (.nix-profile, …); binding an island onto
        # one then aborts. Only --chdir into the tmpfs instead; the islands below
        # still bind as fresh mountpoints.
        if [[ "$pwd_abs" == "$HOME" ]]; then
          args+=(--chdir "$HOME")
        else
          args+=(--bind "$pwd_abs" "$pwd_abs" --chdir "$pwd_abs")
        fi

        bind_rw "$HOME/.cargo"
        bind_rw "$HOME/.cache/gh"
        ${bindsRW}
        bind_ro "$HOME/.config/direnv"
        bind_ro "$HOME/.config/gh"
        bind_ro "$HOME/.config/git"
        bind_ro "$HOME/.local/share/direnv"
        bind_ro "$HOME/.local/state/nix"
        bind_ro "$HOME/.nix-profile"

        # Scoped GnuPG. Config RO; public keybox copied to a throwaway dir and
        # bound RW (below); private-keys-v1.d is NEVER bound — signing goes
        # through the host gpg-agent over its socket, so private keys never
        # enter the jail.
        #
        # public-keys.d is a keyboxd SQLite keybox that needs a WRITABLE dir
        # even for read-only key lookups (keyboxd takes a dotlock inside it), so
        # a plain RO bind returns EROFS and gpg reports "no default secret key:
        # Read-only file system". We copy public-keys.d + trustdb.gpg to a
        # per-launch temp dir, strip stale locks, and bind the copies RW; the
        # AI's writes land on the throwaway copy and are discarded on exit, so
        # the real keyring cannot be mutated. pubring.kbx does not exist under
        # use-keyboxd, so its former bind is dropped.
        #
        # Fallback if signing breaks: replace this whole block with
        # `bind_rw "$HOME/.gnupg"` AND `bind_rw "/run/user/$(id -u)/gnupg"` — the
        # second is required because the --tmpfs below removes host gpg-agent
        # socket access, so `bind_rw "$HOME/.gnupg"` alone would restore the
        # keyring but leave signing broken. This block is shared, so the fallback
        # loosens BOTH clients together; the coupling is accepted by design (same
        # gpg-agent/user/host, low-risk rare path). No per-client gnupg scoping —
        # YAGNI unless a client-specific signing failure actually appears.
        bind_ro "$HOME/.gnupg/gpg.conf"
        bind_ro "$HOME/.gnupg/gpg-agent.conf"
        bind_ro "$HOME/.gnupg/common.conf"

        if [[ -n "''${XDG_RUNTIME_DIR:-}" ]] && [[ -d "$XDG_RUNTIME_DIR" ]]; then
          gnupg_tmp="$XDG_RUNTIME_DIR/${name}-gnupg.$$"
          mkdir -p "$gnupg_tmp"
        else
          gnupg_tmp=$(mktemp -d)
        fi
        # If a copy fails partway, drop the partial so the bind guard below skips
        # it and gpg falls back cleanly instead of binding a truncated keybox.
        if [[ -d "$HOME/.gnupg/public-keys.d" ]]; then
          if cp -a "$HOME/.gnupg/public-keys.d/." "$gnupg_tmp/public-keys.d/"; then
            rm -f "$gnupg_tmp/public-keys.d/".#lk* "$gnupg_tmp/public-keys.d/"*.lock
          else
            rm -rf "$gnupg_tmp/public-keys.d"
          fi
        fi
        if [[ -e "$HOME/.gnupg/trustdb.gpg" ]]; then
          cp -a "$HOME/.gnupg/trustdb.gpg" "$gnupg_tmp/trustdb.gpg" || rm -f "$gnupg_tmp/trustdb.gpg"
        fi
        [[ -d "$gnupg_tmp/public-keys.d" ]] && args+=(--bind "$gnupg_tmp/public-keys.d" "$HOME/.gnupg/public-keys.d")
        [[ -e "$gnupg_tmp/trustdb.gpg" ]]   && args+=(--bind "$gnupg_tmp/trustdb.gpg"   "$HOME/.gnupg/trustdb.gpg")

        # Confine keyboxd to the jail: tmpfs over the agent socket dir, then bind
        # only the two gpg-agent sockets. With S.keyboxd unreachable the jailed
        # gpg cannot connect to a host keyboxd; it launches its own against the
        # copied keybox above, so the tamper protection holds regardless of host
        # state. The --tmpfs MUST be appended BEFORE the socket binds, or bwrap
        # mounts it over them and they vanish. S.gpg-agent.ssh is deliberately
        # bound (the ssh bridge / SSH_AUTH_SOCK block below reuse it); dropping
        # either socket breaks signing or the ssh bridge — do not remove one in a
        # later cleanup.
        args+=(--tmpfs "/run/user/$(id -u)/gnupg")
        bind_rw "/run/user/$(id -u)/gnupg/S.gpg-agent"
        bind_rw "/run/user/$(id -u)/gnupg/S.gpg-agent.ssh"

        # HM-managed ~/.ssh/{config,known_hosts} symlink into /nix/store
        # (root-owned → appears nobody in the userns, which OpenSSH rejects);
        # copy to a per-launch dir under $XDG_RUNTIME_DIR.
        if [[ -n "''${XDG_RUNTIME_DIR:-}" ]] && [[ -d "$XDG_RUNTIME_DIR" ]]; then
          ssh_tmp="$XDG_RUNTIME_DIR/${name}-ssh.$$"
          mkdir -p "$ssh_tmp"
        else
          ssh_tmp=$(mktemp -d)
        fi
        [[ -e "$HOME/.ssh/config" ]]      && cp "$HOME/.ssh/config"      "$ssh_tmp/config"      && chmod 600 "$ssh_tmp/config"
        [[ -e "$HOME/.ssh/known_hosts" ]] && cp "$HOME/.ssh/known_hosts" "$ssh_tmp/known_hosts" && chmod 644 "$ssh_tmp/known_hosts"
        [[ -e "$ssh_tmp/config" ]]      && args+=(--ro-bind "$ssh_tmp/config"      "$HOME/.ssh/config")
        [[ -e "$ssh_tmp/known_hosts" ]] && args+=(--bind    "$ssh_tmp/known_hosts" "$HOME/.ssh/known_hosts")

        if [[ -n "''${SSH_AUTH_SOCK:-}" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
          args+=(--bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
        fi

        # notify-send (Notification hook) needs the bus socket + address.
        dbus_sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
        if [[ -S "$dbus_sock" ]]; then
          args+=(--bind "$dbus_sock" "$dbus_sock")
          args+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$dbus_sock")
        fi

        # `use flake ../sibling` in .envrc needs the sibling dir bound (RW).
        if [[ -r .envrc ]]; then
          envrc_flake_paths=()

          # `|| [[ -n "$line" ]]` keeps the last line if .envrc lacks a
          # trailing newline, otherwise it's silently dropped.
          while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]*use[[:space:]_]flake[[:space:]]+([^[:space:]]+) ]]; then
              envrc_flake_paths+=("''${BASH_REMATCH[1]}")
            fi
          done < .envrc
          for raw_path in "''${envrc_flake_paths[@]}"; do
            unquoted="$raw_path"
            unquoted="''${unquoted#\"}"; unquoted="''${unquoted%\"}"
            unquoted="''${unquoted#\'}"; unquoted="''${unquoted%\'}"
            flake_path="''${unquoted%%#*}"

            # Non-local refs (github:owner/repo, git+file://, ...) don't
            # map to a host directory.
            case "$flake_path" in
              .*|/*) ;;
              *) continue ;;
            esac
            flake_abs=$(realpath -e "$flake_path" 2>/dev/null) || continue
            args+=(--bind "$flake_abs" "$flake_abs")
          done
        fi

        args+=(
          --setenv HOME  "$HOME"
          --setenv USER  "''${USER:-$(id -un)}"
          --setenv TERM  "''${TERM:-xterm-256color}"
          --setenv PATH  ${pathSetenv}
          --setenv SHELL "''${SHELL:-/bin/sh}"
        )
        for var in ${lib.concatStringsSep " " envAllowlist}; do
          pass_env "$var"
        done

        exec ${bwrap} "''${args[@]}" ${policy.rawBinary} ${unleashStr} "$@"
      '';
    in
    {
      inherit wrapper;
      inherit (policy) rawBinary unleashFlags markerEnv;
    };
in
{
  inherit mkJail clients;
}
