{ inputs, ... }:
{
  perSystem =
    { system, lib, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      # aarch64-linux only. systems.nix also lists x86_64-linux, where the
      # real-config check's nixvim package does not exist and `nix flake check`
      # would fail on the only host this repo has.
      checks = lib.optionalAttrs (system == "aarch64-linux") (
        import ./_zellij/copy-mode-tests.nix {
          inherit pkgs;
          inherit (pkgs) lib;
          realNvim = inputs.self.nixosConfigurations.mbp-m2.config.programs.nixvim.build.package;
        }
      );
    };

  flake.modules.nixos.zellij = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.zellij ];
  };

  flake.modules.homeManager.zellij =
    {
      pkgs,
      lib,
      config,
      osConfig,
      ...
    }:
    let
      cfg = config.zellijLlm;

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
        # Swallow errors so a rename hiccup never blocks the editor.
        if [ -n "''${NVIM_PROJECT_NAME:-}" ]; then
          zellij action rename-pane "$NVIM_PROJECT_NAME" >/dev/null 2>&1 || true
        fi
        exec nvim --listen "$sock" "''${files[@]}"
      '';

      lvim = pkgs.writeShellScriptBin "lvim" ''
        set -u
        export PATH=${binPath}:$PATH

        # Already inside a zellij session (lvim run from an agent or float
        # shell): run the real editor directly, never nest a session.
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
        export NVIM_PROJECT_NAME="$(basename "$root")"
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

      # Zellij's scrollback editor. NOT in home.packages: its binary is named
      # `nvim` (zellij requires that basename to pass the +N cursor line), so
      # putting it on PATH would shadow the real editor. Referenced by absolute
      # store path only. The same trap is already documented at the top of this
      # file for neovim itself.
      #
      # nixvim is configured at the NixOS level, so the real editor is on
      # osConfig, not config -- the home-manager attribute of the same name is
      # an unconfigured neovim.
      copy-mode = import ./_zellij/copy-mode.nix {
        inherit pkgs lib;
        nvim = osConfig.programs.nixvim.build.package;
      };

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

      # Three parts so the agent keybind drops when the llm layer is off. The
      # middle part uses double-quoted strings, not an indented block, so its
      # 8-space indent survives dedent.
      agentBind = lib.optionalString cfg.enable (
        "        // NewTab reads `layout` as a layout name, not an inline block\n"
        + "        // (zellij kdl parser), so reference the agent layout by name.\n"
        + "        bind \"Alt t\" { NewTab { layout \"agent\"; }; }\n"
      );

      keybindsHead = ''
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
                bind "Alt h" { GoToPreviousTab; }
                bind "Alt l" { GoToNextTab; }
      '';

      keybindsTail = ''
                bind "Alt Shift t" { NewTab; }
                bind "Alt e" { SwitchToMode "Scroll"; }
                bind "Alt s" { EditScrollback; }
                bind "Alt x" { CloseTab; }
            }
            scroll {
                bind "Esc" "Enter" { SwitchToMode "Locked"; }
                // SwitchToMode "Locked" is not cosmetic. Without it, Alt-e ->
                // find it -> Alt-s leaves zellij in Scroll mode on top of the
                // nvim pane, where zellij eats j and k before nvim sees them.
                bind "Alt s"       { EditScrollback; SwitchToMode "Locked"; }
                // zellij's own default scroll-mode `e` already opens the
                // scrollback editor and lands in Normal mode. This config
                // never sets clear-defaults, so that binding is still live;
                // rebinding it here is cheaper than clearing the defaults and
                // keeps both entry points (Alt-s and `e`) landing in the same
                // zellij mode.
                bind "e"           { EditScrollback; SwitchToMode "Locked"; }
            }
        }
      '';
    in
    {
      options.zellijLlm.enable = lib.mkEnableOption ''
        the zellij LLM/editor layer (nvim wrappers, nvim/agent layouts, Alt-t
        agent tab, the `lvim` project launcher). Off by default for headless hosts'';

      config = {
        stylix.targets.zellij.colors.override.withHashtag = {
          # Swap the mauve accent for blue in zellij only (focused-pane border +
          # selected tab + table title). The RHS reads the global palette, so this
          # is a clean swap with no circular reference.
          base0E = config.lib.stylix.colors.withHashtag.base0D;
          base0D = config.lib.stylix.colors.withHashtag.base0E;
        };

        programs.zellij = {
          enable = true;
          # Start zellij through `lvim`, not in every terminal.
          settings.default_mode = "locked";
          # Resurrection replays each pane's live argv; a jailed agent tab's
          # space-containing `--setenv NIX_CFLAGS_COMPILE "…"` bwrap args get split
          # on whitespace, so a resurrected pane dies with `bwrap: Unknown option
          # -isystem`. Disabling serialization removes the dump entirely.
          settings.session_serialization = false;
          # Copy mode: a real nvim buffer over the pane's scrollback. The wrapper
          # dispatches, because this option is global -- it also captures `zellij
          # edit`, `zellij action edit`, and plugin file-opens, which must reach a
          # normal editable editor. See _zellij/copy-mode.nix.
          #
          # zellij tracks nixpkgs-unstable, and three mechanisms this depends on
          # degrade SILENTLY if upstream moves: the +N editor-basename gate, the
          # $TMPDIR/<uuid>.dump path shape the wrapper's dispatch and rm key off,
          # and OSC-52 interception. warnIf rather than assert: a bump is usually
          # still fine, and a hard failure would hold `nix flake update` hostage
          # to a manual source review.
          settings.scrollback_editor =
            lib.warnIf (!lib.hasPrefix "0.44." config.programs.zellij.finalPackage.version)
              ''
                zellij is now ${config.programs.zellij.finalPackage.version}; copy mode's
                mechanism assumptions were read from 0.44.3 source. Re-check them against the
                new source -- see the comments in modules/programs/_zellij/copy-mode.nix.
              ''
              "${copy-mode}/bin/nvim";
          # copy_command MUST STAY UNSET. Setting it makes zellij run a copy
          # command server-side on the laptop, which breaks the phone -- the exact
          # case the OSC-52 path in _zellij/copy-mode-overlay.lua exists to serve.
          # Zellij intercepts nvim's OSC 52 and re-emits it through its own
          # clipboard_provider, which reaches whichever client is attached.
          # Keep nvim keys available; only Alt bindings and Ctrl-g are intercepted.
          extraConfig = keybindsHead + agentBind + keybindsTail;
          layouts = lib.mkIf cfg.enable {
            nvim = nvimLayout;
            agent = agentLayout;
          };
        };

        # zj (session picker) is always available; the project/agent wrappers
        # only when the llm layer is on.
        home.packages =
          lib.optionals cfg.enable [
            lvim
            nvim-tab
          ]
          ++ [ zj ];
      };
    };
}
