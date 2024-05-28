{ pkgs, config, ... }:

{
  home.packages = [ pkgs.hyprlock ];

  xdg.configFile."hypr/hyprlock.conf".text = let
    # palette = config.colorScheme.palette;
  in ''
    background {
      monitor =
      path = screenshot
      blur_size = 6
      blur_passes = 2
    }

    label {
      monitor =
      text = <b>$USER $TIME</b>
      text_align = center
      font_size = 40
      font_family = FiraCode Nerd Font

      position = 1000, 700
      halign = center
      valign = center
    }

    label {
      monitor =
      text = <i>$LAYOUT</i>
      text_align = right
      font_size = 20
      font_family = FiraCode Nerd Font

      position = 1000, 650
      halign = center
      valign = center
    }

    input-field {
      monitor =
      size = 400, 50
      outline_thickness = 4
      dots_size = 0.33 # Scale of input-field height, 0.2 - 0.8
      dots_spacing = 0.15 # Scale of dots' absolute size, 0.0 - 1.0
      dots_center = true
      dots_rounding = -1 # -1 default circle, -2 follow input-field rounding
      fade_on_empty = true
      fade_timeout = 5000
      placeholder_text =
      hide_input = false
      rounding = -1 # -1 means complete rounding (circle/oval)
      fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i> # can be set to empty
      fail_transition = 300 # transition time in ms between normal outer_color and fail_color
      numlock_color = -1
      bothlock_color = -1 # when both locks are active. -1 means don't change outer color (same for above)

      position = 0, -300
      halign = center
      valign = center
    }
  '';
}
