{ ... }:
{
  flake.modules.homeManager.hyprland =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      wayland.windowManager.hyprland =
        let
          inherit (lib.generators) mkLuaInline;
          toLua = lib.generators.toLua { };
          # Hyprland's key parser splits on '+' and trims. The Lua-side
          # concatenations (modshift, and the extraConfig loop) spell the
          # separator out again — it can't be centralized past the Nix boundary.
          withMod = key: mkLuaInline ''mod .. " + ${key}"'';
          withModShift = key: mkLuaInline ''modshift .. " + ${key}"'';
          exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${toLua cmd})";
          execApp = cmd: exec "uwsm app -- ${cmd}";
          # `_args` renders the attrset as positional arguments
          # (`hl.bind(key, dispatcher, opts)`) rather than as a single table
          # argument.
          mkBind = key: dispatcher: {
            _args = [
              key
              dispatcher
            ];
          };
          mkBindWithOpts = key: dispatcher: opts: {
            _args = [
              key
              dispatcher
              opts
            ];
          };
          lockedRepeat = {
            locked = true;
            repeating = true;
          };
          # linux/input-event-codes.h — Hyprland has no symbolic aliases
          buttonLeft = "mouse:272";
          buttonRight = "mouse:273";
          terminal = lib.getExe config.terminal;
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          cliphist-paste = pkgs.writeShellScript "cliphist-paste" ''
            ${cliphist} list |
              ${wofi} --dmenu |
              ${cliphist} decode |
              ${wl-copy} && ${wtype} -s 10 -M ctrl -s 10 -M shift -s 10 -k V
          '';
          grim = lib.getExe pkgs.grim;
          satty = lib.getExe pkgs.satty;
          wofi = lib.getExe pkgs.wofi;
          wpctl = lib.getExe' pkgs.wireplumber "wpctl";
          wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
          wtype = lib.getExe pkgs.wtype;
        in
        {
          settings = {
            # `_var` entries render as hoisted Lua locals (`local mod = "SUPER"`)
            # instead of `hl.<name>(...)` calls. Every bind below and the
            # extraConfig loop read them. Home Manager emits the locals sorted
            # alphabetically, which is why modshift can reference mod.
            mod = {
              _var = "SUPER";
            };
            modshift = {
              _var = mkLuaInline ''mod .. " + SHIFT"'';
            };

            bind = [
              (mkBind (withModShift "Return") (execApp terminal))
              (mkBind (withModShift "C") (mkLuaInline "hl.dsp.window.close()"))
              (mkBind (withMod "P") (execApp "${wofi} --show run"))
              (mkBind (withModShift "L") (execApp "hyprlock-once"))
              # `exec`, not `execApp`: this bind deliberately skips the
              # `uwsm app --` prefix the others use. Adding it would change
              # the bind's behavior.
              (mkBind (withMod "I") (exec "amphetamine-toggle"))

              # scratchpads
              (mkBind (withMod "X") (mkLuaInline ''hl.dsp.workspace.toggle_special("kitty")''))

              # cycle workspaces
              (mkBind (withMod "H") (mkLuaInline ''hl.dsp.focus({ workspace = "-1" })''))
              (mkBind (withMod "L") (mkLuaInline ''hl.dsp.focus({ workspace = "+1" })''))

              # cycle windows, raising whatever the cycle just focused.
              # hl.dsp.* returns dispatcher userdata, not a callable; inside a
              # function body each one needs hl.dispatch().
              (mkBind (withMod "Tab") (mkLuaInline ''
                function()
                  hl.dispatch(hl.dsp.window.cycle_next())
                  hl.dispatch(hl.dsp.window.bring_to_top())
                end''))
              (mkBind (withModShift "Tab") (mkLuaInline "hl.dsp.window.swap({ next = true })"))

              # clipboard
              (mkBind (withMod "V") (execApp "${cliphist-paste}"))
              (mkBind (withModShift "V") (execApp "${cliphist} wipe"))

              # media
              (mkBind "XF86SelectiveScreenshot" (
                execApp "${grim} - | ${satty} -f - --fullscreen --initial-tool crop --copy-command ${wl-copy} --actions-on-enter save-to-clipboard --early-exit"
              ))

              # mouse-drag floating windows. `mouse = true` mirrors the
              # hyprland.lua example Hyprland ships.
              (mkBindWithOpts (withMod buttonLeft) (mkLuaInline "hl.dsp.window.drag()") { mouse = true; })
              (mkBindWithOpts (withMod buttonRight) (mkLuaInline "hl.dsp.window.resize()") { mouse = true; })

              (mkBindWithOpts "XF86AudioMute" (execApp "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle") {
                locked = true;
              })
              (mkBindWithOpts "XF86AudioMicMute" (execApp "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle") {
                locked = true;
              })

              (mkBindWithOpts "XF86AudioRaiseVolume" (execApp "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%+")
                lockedRepeat
              )
              (mkBindWithOpts "XF86AudioLowerVolume" (execApp "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%-")
                lockedRepeat
              )
              # Keyboard brightness keys sync touchbar and kbd_backlight
              (mkBindWithOpts "XF86KbdBrightnessDown" (execApp "touchbar-kbd-sync down") lockedRepeat)
              (mkBindWithOpts "XF86KbdBrightnessUp" (execApp "touchbar-kbd-sync up") lockedRepeat)
              # Display brightness keys control display only
              (mkBindWithOpts "XF86MonBrightnessDown" (execApp "${brightnessctl} set 1%-") lockedRepeat)
              (mkBindWithOpts "XF86MonBrightnessUp" (execApp "${brightnessctl} set 1%+") lockedRepeat)
            ];
          };

          # extraConfig renders last, so the locals are in scope.
          extraConfig = ''
            for i = 1, 10 do
              local key = i % 10 -- workspace 10 is on the 0 key
              hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
              hl.bind(modshift .. " + " .. key, hl.dsp.window.move({ workspace = i }))
            end
          '';
        };
    };
}
