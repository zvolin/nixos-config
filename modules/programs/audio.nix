{ ... }:
{
  flake.modules.homeManager.audio =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib.generators) mkLuaInline;
      toLua = lib.generators.toLua { };
      terminal = lib.getExe config.terminal;
      wiremix = lib.getExe pkgs.wiremix;
      audioToggle = pkgs.writeShellApplication {
        name = "audio-toggle";
        runtimeInputs = [
          config.wayland.windowManager.hyprland.package
          pkgs.jq
        ];
        text = ''
          wiremix_addr=$(hyprctl clients -j \
            | jq -r '[.[] | select(.class == "wiremix") | .address] | first // empty')
          active_addr=$(hyprctl activewindow -j | jq -r '.address // empty')

          if [ -z "$wiremix_addr" ]; then
            exec uwsm app -- ${terminal} --class wiremix -e ${wiremix}
          elif [ "$wiremix_addr" = "$active_addr" ]; then
            hyprctl dispatch 'hl.dsp.window.close()'
          else
            hyprctl dispatch "hl.dsp.focus({ window = 'address:$wiremix_addr' })"
          fi
        '';
      };
      audioToggleExe = lib.getExe audioToggle;
    in
    {
      # wiremix - TUI audio mixer for PipeWire
      home.packages = [
        pkgs.wiremix
        audioToggle
      ];

      # SUPER+A cycles wiremix: launch, focus, kill
      wayland.windowManager.hyprland.settings = {
        window_rule = [
          {
            name = "audio-wiremix-float";
            match.class = "wiremix";
            float = true;
            center = true;
            size = "800 500";
          }
        ];
        bind = [
          {
            # A literal, not a reference to the `mod` local the hyprland module
            # declares: a Lua-side reference is invisible to Nix, so a broken
            # one fails at Hyprland's config load instead of at eval.
            _args = [
              "SUPER + A"
              (mkLuaInline "hl.dsp.exec_cmd(${toLua audioToggleExe})")
            ];
          }
        ];
      };
    };
}
