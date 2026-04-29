{
  pkgs,
  lib,
  inputs,
  ...
}: let
  # landrun tests use Landlock syscalls that fail inside Nix's build sandbox
  pkgs' = pkgs.extend (_: prev: {
    landrun = prev.landrun.overrideAttrs {
      doCheck = false;
      doInstallCheck = false;
    };
  });
  sandnixLib = import "${inputs.sandnix}/nix/lib.nix" {pkgs = pkgs';};

  # Env vars to pass through the sandbox
  # Core (TERM/LANG/LC_ALL overlap with features.tty; XDG_RUNTIME_DIR overlaps
  # with features.dbus via gh module — duplicates are harmless, listed for clarity)
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

  # Tokens (preloaded by wrapper)
  tokenEnv = [
    "GH_TOKEN"
    "GITHUB_PERSONAL_ACCESS_TOKEN"
  ];

  # Claude
  claudeEnv = [
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
    "CLAUDE_SANDBOX"
  ];

  # Nix devshell (compilers, toolchain, stdenv)
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

  # aarch64-linux arch sentinels
  archEnv = [
    "NIX_CC_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_CC_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
  ];

  allEnv = coreEnv ++ tokenEnv ++ claudeEnv ++ nixDevshellEnv ++ archEnv;

  claude-sandboxed = sandnixLib.makeSandnix {
    name = "claude";
    modules = [
      inputs.sandnix.sandnixModules.gh
      inputs.sandnix.sandnixModules.git
      {
        program = "${pkgs.claude-code}/bin/claude";
        features = {
          tty = true;
          nix = true;
          network = true;
          tmp = true;
        };
        cli = {
          rwx = [
            "$HOME/.claude" # plugins need execve() — Landlock requires EXECUTE
            "." # project directory
          ];
          rw = [
            "$HOME/.claude.json"
            "$XDG_RUNTIME_DIR" # Wayland/D-Bus sockets for notify-send
            "$HOME/.gnupg" # commit signing keyring + trustdb
            "$HOME/.ferrex" # ferrex MCP database + log
            "$HOME/.serena" # serena MCP user-level state
            "$HOME/.cargo" # cargo registry/git/target caches for rust builds
            "$HOME/.cache/gh" # gh CLI ephemeral cache (narrow, not all of ~/.cache)
          ];
          ro = [
            "$HOME/.local/share/gh" # gh state on Linux (token store fallback)
            "$HOME/.local/state/nix" # nix CLI state, registry
            "$HOME/.nix-profile" # user nix profile symlink
            "$HOME/.ssh/config" # ssh client config (git over ssh)
            "$HOME/.ssh/known_hosts" # host key verification
          ];
          env = allEnv;
        };
      }
    ];
  };

  # Wrapper: preload GH token, ensure .claude.json exists, set CLAUDE_SANDBOX, exec sandboxed binary
  claude-wrapper = pkgs.writeShellScriptBin "claude" ''
    # Preload GitHub token
    if [ -z "''${GH_TOKEN:-}" ]; then
      GH_TOKEN=$(${lib.getExe pkgs.gh} auth token 2>/dev/null) || true
    fi
    export GH_TOKEN
    export GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"

    # First-run safety: landrun may error on nonexistent --rw paths
    touch "$HOME/.claude.json" 2>/dev/null || true

    # Sandbox detection for hooks
    export CLAUDE_SANDBOX=1

    exec ${claude-sandboxed}/bin/claude "$@"
  '';

  # Propagate meta from original package — HM module may access cfg.package.meta
  # (e.g., for symlinkJoin when plugins are configured)
  claude-wrapped =
    claude-wrapper
    // {
      meta = (pkgs.claude-code.meta or {}) // {mainProgram = "claude";};
    };
in {
  programs.claude-code.package = claude-wrapped;
}
