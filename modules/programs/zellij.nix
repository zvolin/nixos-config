{ inputs, ... }:
{
  flake.modules.nixos.zellij = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.zellij ];
  };

  flake.modules.homeManager.zellij =
    { pkgs, lib, ... }:
    let
      # Prepended, not replaced, so agent binaries already on PATH still
      # resolve when these scripts exec nvim or an agent. neovim is deliberately
      # absent: `nvim` must resolve to the user's configured editor (nixvim's
      # wrapper on the system PATH), never a bare nixpkgs neovim.
      binPath = lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.git
        pkgs.zellij
        pkgs.fzf
      ];

      # Shared top/bottom bars so every tab shows the mode indicator and keybar.
      barsTemplate = ''
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zellij:tab-bar"
            }
            children
            pane size=2 borderless=true {
                plugin location="zellij:status-bar"
            }
        }
      '';

      # Tab 1 launcher. Its session name must match nvim-project's socket name.
      nvim-tab = pkgs.writeShellScriptBin "nvim-tab" ''
        set -u
        export PATH=${binPath}:$PATH
        sock="''${XDG_RUNTIME_DIR:-/tmp}/nvim-''${ZELLIJ_SESSION_NAME:-project}.sock"
        files=()
        if [ -n "''${NVIM_PROJECT_FILES:-}" ]; then
          while IFS= read -r f; do
            [ -n "$f" ] && files+=("$f")
          done <<< "''${NVIM_PROJECT_FILES}"
        fi
        exec nvim --listen "$sock" "''${files[@]}"
      '';

      nvim-project = pkgs.writeShellScriptBin "nvim-project" ''
        set -u
        export PATH=${binPath}:$PATH

        # Already inside a zellij session (edit-scrollback opening $EDITOR, or an
        # nvim typed in an agent/float shell): run the real editor, never nest.
        if [ -n "''${ZELLIJ:-}" ]; then
          exec nvim "$@"
        fi

        root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        name=$(printf '%s-%s' \
          "$(basename "$root")" \
          "$(printf '%s' "$root" | sha1sum | cut -c1-3)" \
          | tr -c 'a-zA-Z0-9_-' '-')
        sock="''${XDG_RUNTIME_DIR:-/tmp}/nvim-$name.sock"

        if zellij list-sessions -sn 2>/dev/null | grep -qxF "$name"; then
          # --remote uses the server's cwd, so preserve the caller's paths.
          if [ "$#" -gt 0 ]; then
            abs=()
            for f in "$@"; do abs+=("$(realpath -m -- "$f")"); done
            nvim --server "$sock" --remote "''${abs[@]}" >/dev/null 2>&1 || true
          fi
          exec zellij attach -f "$name"
        fi

        export NVIM_PROJECT_FILES="$(printf '%s\n' "$@")"
        exec zellij --layout nvim attach -c "$name"
      '';

      nvimLayout = ''
        layout {
            ${barsTemplate}
            tab name="nvim" focus=true {
                pane command="${nvim-tab}/bin/nvim-tab"
            }
        }
      '';

      ai-launch = import ./_ai-launch.nix { inherit pkgs lib; };

      agentLayout = ''
        layout {
            ${barsTemplate}
            tab name="agent" {
                pane command="${ai-launch}/bin/ai-launch" close_on_exit=true
            }
        }
      '';

      zj = pkgs.writeShellScriptBin "zj" ''
        set -u
        export PATH=${binPath}:$PATH
        session=$(zellij list-sessions -sn 2>/dev/null | fzf \
          --layout=reverse --border=rounded --info=hidden \
          --header="attach zellij session") || exit 0
        [ -n "$session" ] || exit 0
        exec zellij attach -f "$session"
      '';
    in
    {
      programs.zellij = {
        enable = true;
        # Start zellij through the nvim alias, not in every terminal.
        settings.default_mode = "locked";
        # Keep nvim keys available; only Alt bindings and Ctrl-g are intercepted.
        extraConfig = ''
          keybinds {
              locked {
                  bind "Alt 1" { GoToTab 1; }
                  bind "Alt 2" { GoToTab 2; }
                  bind "Alt 3" { GoToTab 3; }
                  bind "Alt 4" { GoToTab 4; }
                  bind "Alt 5" { GoToTab 5; }
                  bind "Alt 6" { GoToTab 6; }
                  bind "Alt 7" { GoToTab 7; }
                  bind "Alt 8" { GoToTab 8; }
                  bind "Alt 9" { GoToTab 9; }
                  bind "Alt [" { GoToPreviousTab; }
                  bind "Alt ]" { GoToNextTab; }
                  // NewTab reads `layout` as a layout name, not an inline block
                  // (zellij kdl parser), so reference the agent layout by name.
                  bind "Alt a" { NewTab { layout "agent"; }; }
                  bind "Alt e" { EditScrollback; }
                  bind "Alt x" { CloseTab; }
              }
          }
        '';
        layouts.nvim = nvimLayout;
        layouts.agent = agentLayout;
      };

      home.packages = [
        nvim-project
        nvim-tab
        zj
      ];
    };
}
