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
            hyprctl dispatch killactive
          else
            hyprctl dispatch focuswindow "address:$wiremix_addr"
          fi
        '';
      };
    in
    {
      # wiremix - TUI audio mixer for PipeWire
      home.packages = [
        pkgs.wiremix
        audioToggle
      ];

      # Float wiremix window and bind SUPER+A to the three-state toggle
      wayland.windowManager.hyprland.settings = {
        windowrule = [
          "float on, match:class wiremix"
          "center on, match:class wiremix"
          "size 800 500, match:class wiremix"
        ];
        bind = [
          "SUPER, A, exec, ${lib.getExe audioToggle}"
        ];
      };
    };
}
