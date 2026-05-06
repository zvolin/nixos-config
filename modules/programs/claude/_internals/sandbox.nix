{
  pkgs,
  lib,
  ...
}: let
  bwrap = lib.getExe pkgs.bubblewrap;
  claude = lib.getExe pkgs.claude-code;

  # After --clearenv we re-inject these explicitly via --setenv.
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
    "GITHUB_PERSONAL_ACCESS_TOKEN"
  ];

  claudeEnv = [
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
    "CLAUDE_SANDBOX"
    "CLAUDE_SESSION_NAME"
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

  envAllowlist = coreEnv ++ tokenEnv ++ claudeEnv ++ nixDevshellEnv ++ archEnv;

  claude-wrapper = pkgs.writeShellScriptBin "claude" ''
    bind_ro() { [[ -e "$1" ]] && args+=(--ro-bind "$1" "$1"); }
    bind_rw() { [[ -e "$1" ]] && args+=(--bind    "$1" "$1"); }
    pass_env() { [[ -n "''${!1:-}" ]] && args+=(--setenv "$1" "''${!1}"); }

    # Preload GH token so the MCP github server has credentials.
    if [ -z "''${GH_TOKEN:-}" ]; then
      GH_TOKEN=$(${lib.getExe pkgs.gh} auth token 2>/dev/null) || true
    fi
    export GH_TOKEN
    export GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"

    # bind_rw skips missing sources, so without pre-creation any first-time
    # write lands in the tmpfs $HOME and dies on exit.
    mkdir -p \
      "$HOME/.claude" \
      "$HOME/.ferrex" \
      "$HOME/.serena" \
      "$HOME/.cargo" \
      "$HOME/.codex" \
      "$HOME/.cache/gh"
    touch "$HOME/.claude.json" 2>/dev/null || true

    export CLAUDE_SANDBOX=1

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
    args+=(--bind "$pwd_abs" "$pwd_abs" --chdir "$pwd_abs")

    bind_rw "$HOME/.claude"
    bind_rw "$HOME/.claude.json"
    bind_rw "$HOME/.gnupg"
    bind_rw "$HOME/.ferrex"
    bind_rw "$HOME/.serena"
    bind_rw "$HOME/.cargo"
    bind_rw "$HOME/.cache/gh"
    bind_rw "$HOME/.codex"
    bind_ro "$HOME/.config/direnv"
    bind_ro "$HOME/.config/gh"
    bind_ro "$HOME/.config/git"
    bind_ro "$HOME/.local/share/direnv"
    bind_ro "$HOME/.local/state/nix"
    bind_ro "$HOME/.nix-profile"

    # GnuPG >= 2.1.13 puts the agent socketdir at /run/user/$UID/gnupg, not
    # ~/.gnupg. Without this bind, signing fails with "no pinentry".
    bind_rw "/run/user/$(id -u)/gnupg"

    # HM-managed ~/.ssh/{config,known_hosts} symlink into /nix/store
    # (root-owned). In the user namespace they appear owned by `nobody`,
    # which OpenSSH rejects, so copy them to a per-launch dir under
    # $XDG_RUNTIME_DIR (a Ctrl-C between copy and exec would leak a /tmp
    # dir; $XDG_RUNTIME_DIR is wiped at logout). known_hosts is rw to the
    # copy so first-contact host adds work; writes don't escape.
    if [[ -n "''${XDG_RUNTIME_DIR:-}" ]] && [[ -d "$XDG_RUNTIME_DIR" ]]; then
      ssh_tmp="$XDG_RUNTIME_DIR/claude-ssh.$$"
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

    # notify-send (Notification hook) needs the bus socket plus
    # DBUS_SESSION_BUS_ADDRESS; no other dbus services are reachable.
    dbus_sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
    if [[ -S "$dbus_sock" ]]; then
      args+=(--bind "$dbus_sock" "$dbus_sock")
      args+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$dbus_sock")
    fi

    # When .envrc has `use flake ../sibling`, anything that re-resolves the
    # path inside Claude (nix develop, nix build, editing the sibling's
    # flake.nix) needs that directory bound. RW so Claude can edit it.
    # Heuristic only: non-local refs (github:, git+file://, ...) and
    # computed paths surface as ENOENT, fix by restructuring the .envrc.
    if [[ -r .envrc ]]; then
      envrc_flake_paths=()

      # `|| [[ -n "$line" ]]` keeps the last line if .envrc lacks a trailing
      # newline, otherwise it's silently dropped.
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

        # Non-local refs (github:owner/repo, git+file://, ...) don't map to
        # a host directory.
        case "$flake_path" in
          .*|/*) ;;
          *) continue ;;
        esac

        # Skip silently on a missing path; direnv would fail too, so
        # there's nothing to bind.
        flake_abs=$(realpath -e "$flake_path" 2>/dev/null) || continue

        args+=(--bind "$flake_abs" "$flake_abs")
      done
    fi

    args+=(
      --setenv HOME  "$HOME"
      --setenv USER  "''${USER:-$(id -un)}"
      --setenv TERM  "''${TERM:-xterm-256color}"
      --setenv PATH  "''${PATH}"
      --setenv SHELL "''${SHELL:-/bin/sh}"
    )
    for var in ${lib.concatStringsSep " " envAllowlist}; do
      pass_env "$var"
    done

    exec ${bwrap} "''${args[@]}" ${claude} "$@"
  '';

  # HM module reads cfg.package.meta (e.g. for symlinkJoin when plugins are
  # configured), so propagate meta from the original package.
  claude-wrapped =
    claude-wrapper
    // {
      meta = (pkgs.claude-code.meta or {}) // {mainProgram = "claude";};
    };
in {
  programs.claude-code.package = claude-wrapped;
}
