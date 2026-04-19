{ ... }:

{
  flake.modules.homeManager.brightness = { pkgs, ... }:
    let
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "touchbar-kbd-sync" ''
          set -e

          # Find touchbar: any backlight device that isn't the main display
          TOUCHBAR=$( \
            ${brightnessctl} -l -c backlight -m \
            | grep -v apple-panel-bl \
            | head -1 \
            | cut -d, -f1 \
          ) || true

          case "$1" in
            up)
              [ -n "$TOUCHBAR" ] && ${brightnessctl} -d "$TOUCHBAR" set 1%+
              ${brightnessctl} --class=leds -d kbd_backlight set 1%+
              ;;
            down)
              [ -n "$TOUCHBAR" ] && ${brightnessctl} -d "$TOUCHBAR" set 1%-
              ${brightnessctl} --class=leds -d kbd_backlight set 1%-
              ;;
            set)
              [ -n "$TOUCHBAR" ] && ${brightnessctl} -d "$TOUCHBAR" set "$2"
              ${brightnessctl} --class=leds -d kbd_backlight set "$2"
              ;;
            off)
              [ -n "$TOUCHBAR" ] && ${brightnessctl} -d "$TOUCHBAR" set 0
              ${brightnessctl} --class=leds -s -d kbd_backlight set 0
              ;;
            restore)
              [ -n "$TOUCHBAR" ] && ${brightnessctl} -d "$TOUCHBAR" -r
              ${brightnessctl} --class=leds -r -d kbd_backlight
              ;;
            *)
              echo "Usage: touchbar-kbd-sync {up|down|set|off|restore}" >&2
              exit 1
              ;;
          esac
        '')
      ];
    };
}
