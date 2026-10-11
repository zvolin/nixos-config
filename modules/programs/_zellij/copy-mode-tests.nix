# Headless checks for copy mode. Registered as flake checks by zellij.nix.
#
# Four of the five inject `pkgs.neovim`: the overlay's logic is self-contained,
# and a bare neovim keeps the sandbox closure small and the checks
# arch-independent. zellij-copy-mode-real-config is the exception, and is the
# one that defends the design choice -- see its comment.
{
  pkgs,
  lib,
  realNvim,
}:
let
  overlay = ./copy-mode-overlay.lua;
  assertions = ./copy-mode-assertions.lua;
  fakeClipboard = ./copy-mode-fake-clipboard.lua;

  # A writable HOME: the nix sandbox hands out /homeless-shelter. The nvim state
  # dir is pre-created because the real config's plugins write logs there.
  sandboxEnv = ''
    export HOME="$PWD/home"
    export TERM=dumb
    mkdir -p "$HOME/.local/share/nvim"
  '';

  # A hung nvim is the failure mode: a Lua error leaves headless nvim sitting at
  # the prompt, so the trailing qa!/cquit! never runs and the build hangs with
  # no output instead of failing. Bound every invocation, and name exit 124 so
  # the cause is obvious.
  runHelper = ''
    run_nvim() {
      local status=0
      timeout 60 "$@" || status=$?
      if [ "$status" -eq 124 ]; then
        echo "nvim hung: a Lua error left it at the prompt, so the trailing qa!/cquit! never ran" >&2
        exit 1
      fi
      return "$status"
    }
  '';

  fixture = ''
    printf 'first line\nsecond line\nthird line\n' > fixture.dump
  '';

  # The wrapper under test, driven against a bare neovim.
  wrapper = import ./copy-mode.nix {
    inherit pkgs lib;
    nvim = pkgs.neovim;
  };
in
{
  zellij-copy-mode-overlay =
    pkgs.runCommand "zellij-copy-mode-overlay"
      {
        nativeBuildInputs = [
          pkgs.neovim
          pkgs.coreutils
        ];
      }
      ''
        ${sandboxEnv}
        ${runHelper}
        ${fixture}
        run_nvim nvim --clean -i NONE --headless \
          -c 'luafile ${overlay}' \
          -c 'luafile ${assertions}' \
          fixture.dump
        touch $out
      '';

  # The check that defends the design choice. The copy buffer IS the real
  # editor, so anything the shared nixvim config grows later -- a BufReadPost
  # autocmd, a `q` mapping -- can collide with a buffer where q, i, a and Esc
  # all quit. A bare neovim under --clean is precisely the configuration in
  # which that collision cannot happen, so it cannot be the only thing tested.
  #
  # No --clean and no -u here: the point is the real config, loaded the way the
  # user loads it.
  zellij-copy-mode-real-config =
    pkgs.runCommand "zellij-copy-mode-real-config"
      {
        nativeBuildInputs = [
          realNvim
          pkgs.coreutils
        ];
      }
      ''
        ${sandboxEnv}
        ${runHelper}
        ${fixture}
        run_nvim nvim -i NONE --headless \
          -c 'luafile ${overlay}' \
          -c 'luafile ${assertions}' \
          fixture.dump
        touch $out
      '';

  # Regression test for the teardown race: neovim defers the clipboard
  # provider's copy call by one event-loop turn, so a `y` mapping that quits
  # inline copies nothing.
  zellij-copy-mode-yank =
    pkgs.runCommand "zellij-copy-mode-yank"
      {
        nativeBuildInputs = [
          pkgs.neovim
          pkgs.coreutils
        ];
      }
      ''
        ${sandboxEnv}
        ${runHelper}
        ${fixture}
        export COPY_MODE_TEST_OUT="$PWD/yanked.txt"
        run_nvim nvim --clean -i NONE --headless \
          -c 'luafile ${overlay}' \
          -c 'luafile ${fakeClipboard}' \
          -c 'lua vim.api.nvim_feedkeys("GVy", "x", false)' \
          fixture.dump
        if [ ! -e "$COPY_MODE_TEST_OUT" ]; then
          echo "y did not reach the clipboard provider before the editor quit" >&2
          exit 1
        fi
        got=$(cat "$COPY_MODE_TEST_OUT")
        if [ "$got" != "third line" ]; then
          echo "clipboard holds '$got', expected 'third line'" >&2
          exit 1
        fi
        touch $out
      '';

  # Negative control: this is what gives the check above its teeth. The extra -c
  # re-maps `y` to the inline-quit form AFTER the overlay has been sourced, and
  # asserts the provider is never reached. Doing it here rather than by editing
  # the overlay means no source file is ever in a broken state.
  zellij-copy-mode-yank-negative =
    pkgs.runCommand "zellij-copy-mode-yank-negative"
      {
        nativeBuildInputs = [
          pkgs.neovim
          pkgs.coreutils
        ];
      }
      ''
        ${sandboxEnv}
        ${runHelper}
        ${fixture}
        export COPY_MODE_TEST_OUT="$PWD/yanked.txt"
        run_nvim nvim --clean -i NONE --headless \
          -c 'luafile ${overlay}' \
          -c 'luafile ${fakeClipboard}' \
          -c "lua vim.keymap.set('x', 'y', 'y<Cmd>qa!<CR>', { buffer = 0, silent = true })" \
          -c 'lua vim.api.nvim_feedkeys("GVy", "x", false)' \
          fixture.dump
        if [ -e "$COPY_MODE_TEST_OUT" ]; then
          echo "the inline-quit y mapping reached the provider, so the yank check has no teeth" >&2
          exit 1
        fi
        touch $out
      '';

  # The wrapper's dispatch is the destructive path: the copy branch rm's its
  # argument. These cases pin it.
  zellij-copy-mode-dispatch =
    pkgs.runCommand "zellij-copy-mode-dispatch"
      {
        nativeBuildInputs = [
          pkgs.neovim
          pkgs.coreutils
        ];
      }
      ''
        ${sandboxEnv}
        ${runHelper}
        mkdir -p "$PWD/tmp/sub"
        export TMPDIR="$PWD/tmp"
        wrapper=${wrapper}/bin/nvim

        fail() { echo "$1" >&2; exit 1; }
        seed() { printf 'l1\nl2\nl3\nl4\nl5\n' > "$1"; }
        check_cursor() {
          local uuid=$1 args=$2 expected=$3
          seed "$TMPDIR/$uuid.dump"
          # $args is unquoted so "" splits to nothing and "+2" becomes one token.
          line=$(run_nvim "$wrapper" $args --headless \
            -c 'lua io.stderr:write(vim.fn.line(".") .. "\n")' -c 'qa!' \
            "$TMPDIR/$uuid.dump" 2>&1 | tail -1)
          [ "$line" = "$expected" ] || fail "args '$args' put the cursor on line $line, expected $expected"
        }

        # A direct child of $TMPDIR with a UUID basename ending in .dump is
        # copy mode, and the trap removes it.
        seed "$TMPDIR/1a2b3c4d-5e6f-4a1b-9c2d-3e4f5a6b7c8d.dump"
        run_nvim "$wrapper" +2 --headless \
          -c 'lua if vim.bo.modifiable then vim.cmd("cquit! 1") end' -c 'qa!' \
          "$TMPDIR/1a2b3c4d-5e6f-4a1b-9c2d-3e4f5a6b7c8d.dump" \
          || fail "copy branch opened a modifiable buffer"
        # `if`, not `[ … ] && fail`: under the builder's set -e, a false test at
        # the end of an && list exits the script on the passing case.
        if [ -e "$TMPDIR/1a2b3c4d-5e6f-4a1b-9c2d-3e4f5a6b7c8d.dump" ]; then fail "copy branch left the dump behind"; fi

        # Zellij's failover retry drops the +N; the wrapper appends +$ so the
        # buffer opens at the newest output rather than the top.
        #
        # run_nvim's own `exit 1` cannot escape a $(…) subshell, so a hang here
        # surfaces as a wrong line number rather than a named error. The
        # timeout still bounds it.
        check_cursor "2b3c4d5e-6f7a-4b2c-8d3e-4f5a6b7c8d9e" "" "5"

        # A supplied +N wins over the fallback.
        check_cursor "3c4d5e6f-7a8b-4c3d-9e4f-5a6b7c8d9e0f" "+2" "2"

        check_user_dump() {
          local path=$1 desc=$2
          seed "$path"
          run_nvim "$wrapper" --headless \
            -c 'lua if not vim.bo.modifiable then vim.cmd("cquit! 1") end' -c 'qa!' \
            "$path" \
            || fail "$desc landed in the read-only copy buffer"
          [ -e "$path" ] || fail "$desc was deleted"
        }

        # Nested, so not a dump zellij produced: real editor, file survives.
        # This is the case a `case "$tmp"/*.dump` glob would wrongly match.
        seed "$TMPDIR/sub/nested.dump"
        run_nvim "$wrapper" --headless -c 'qa!' "$TMPDIR/sub/nested.dump"
        [ -e "$TMPDIR/sub/nested.dump" ] || fail "nested .dump was deleted"

        # A user's own file that happens to end in .dump, opened through
        # `zellij edit`: must open editable and must survive.
        check_user_dump "$PWD/notes.dump" "a user's notes.dump"

        # A user's own file inside $TMPDIR, opened through `zellij edit`: the
        # basename is not a zellij dump uuid, so it must open editable and survive.
        check_user_dump "$TMPDIR/notes.dump" "a user's notes.dump inside TMPDIR"

        # An ordinary file open still works.
        echo hello > plain.txt
        run_nvim "$wrapper" --headless -c 'qa!' plain.txt
        [ -e plain.txt ] || fail "plain.txt was deleted"

        touch $out
      '';
}
