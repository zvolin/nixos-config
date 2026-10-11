# The editor zellij's `scrollback_editor` points at.
#
# That option is GLOBAL: `build_command` in zellij's os_input_output.rs uses it
# for every TerminalAction::OpenFile, so it also captures `zellij edit <path>`,
# `zellij action edit`, and the plugin open_file host call used by strider and
# session-manager. Those must reach a normal, editable editor, so this script
# dispatches on its last argument.
#
# `nvim` is injected rather than read out of `config` for two reasons. From a
# home-manager module the real editor is `osConfig.programs.nixvim.build.package`
# -- the HM-level attribute of the same name is a bare, unconfigured neovim --
# and injection is what lets copy-mode-tests.nix drive this script against a
# plain `pkgs.neovim` in the sandbox.
{
  pkgs,
  lib,
  nvim,
}:
let
  # Zellij appends the `+N` cursor line only when the editor path's LAST
  # COMPONENT is exactly one of vim/nvim/emacs/nano/kak (os_input_output.rs
  # uses Path::ends_with, which matches whole components). Renaming this to
  # anything else silently loses the cursor position. The store directory name
  # is free; this is not.
  binName = "nvim";

  overlay = ./copy-mode-overlay.lua;

  # coreutils for the trap's rm.
  binPath = lib.makeBinPath [ pkgs.coreutils ];

  wrapper = pkgs.writeShellScriptBin binName ''
    set -u
    export PATH=${binPath}:$PATH

    real=${lib.getExe' nvim "nvim"}

    if [ "$#" -eq 0 ]; then
      exec "$real"
    fi

    # Zellij dumps scrollback to $TMPDIR/<uuid>.dump and passes `+N <file>`, so
    # the candidate is the LAST argument, not $1.
    dump="''${@: -1}"
    tmp="''${TMPDIR:-/tmp}"
    tmp="''${tmp%/}"

    # The rule enforced here: a direct child of $tmp with a UUID basename.
    # Both parts matter because the copy branch DELETES this file. The
    # directory-and-extension check alone lets through a user's own
    # $TMPDIR/notes.dump opened via `zellij edit` -- global scrollback_editor
    # means that request reaches this same script -- so the basename arm
    # below checks the shape zellij actually generates (Fact 1: it dumps to
    # $TMPDIR/<uuid>.dump), not just the suffix. Parameter expansion rather
    # than a case glob for the directory check, because `*` matches `/` in
    # shell patterns and would let nested paths through.
    if [ "''${dump%/*}" != "$tmp" ] || [ "''${dump##*.}" != "dump" ]; then
      exec "$real" "$@"
    fi

    # If zellij ever changes the dump filename shape, this stops matching and
    # copy mode simply fails to engage -- the file opens in a normal editable
    # buffer instead of being deleted. That's the failure direction we want.
    base="''${dump##*/}"
    case "$base" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-*-*-*-*.dump) ;;
      *) exec "$real" "$@" ;;
    esac

    # Copy mode. Do NOT exec: an exec'd shell is replaced by the new image and
    # its trap never runs, leaving full agent output behind in $TMPDIR. Zellij's
    # pty.rs contains no remove_file, so nothing else cleans these up. $dump is
    # the value the test above already validated.
    trap 'rm -f -- "$dump"' EXIT HUP INT TERM

    # Zellij passes `+N` on the normal path, so this covers its failover retry
    # (which drops the +N) and running the wrapper by hand.
    case "$1" in
      +*) ;;
      *) set -- '+$' "$@" ;;
    esac

    # -i NONE: no shada, so nvim records no cursor position for a path this
    # script is about to delete.
    "$real" -i NONE -c 'luafile ${overlay}' "$@"
    exit $?
  '';
in
# Guards our own rename refactors: `binName` is the identifier a rename would
# touch. It does not guard writeShellScriptBin's output layout -- that is owned
# by zellij-copy-mode-dispatch, which runs ${wrapper}/bin/nvim five times.
assert lib.assertMsg (
  binName == "nvim"
) "zellij only passes the +N cursor line when the editor's basename is exactly nvim";
wrapper
