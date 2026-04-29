{...}: {
  flake.modules.homeManager.audio = {
    pkgs,
    lib,
    config,
    ...
  }: let
    terminal = lib.getExe config.terminal;
    wiremix = lib.getExe pkgs.wiremix;
  in {
    # wiremix - TUI audio mixer for PipeWire
    home.packages = [pkgs.wiremix];

    # Float wiremix window
    wayland.windowManager.hyprland.settings = {
      windowrule = [
        "float on, match:class wiremix"
        "center on, match:class wiremix"
        "size 800 500, match:class wiremix"
      ];
      # Quick keybind: SUPER+A for audio
      bind = [
        "SUPER, A, exec, uwsm app -- ${terminal} --class wiremix -e ${wiremix}"
      ];
    };
  };
}
