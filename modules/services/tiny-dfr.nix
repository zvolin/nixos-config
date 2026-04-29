{...}: {
  flake.modules.nixos.tiny-dfr = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options.services.tiny-dfr.enable = lib.mkEnableOption "tiny-dfr";

    config = lib.mkIf config.services.tiny-dfr.enable {
      environment.systemPackages = [pkgs.tiny-dfr];
      systemd.packages = [pkgs.tiny-dfr];
      services.udev.packages = [pkgs.tiny-dfr];

      # Install font system-wide so the systemd service can access it
      fonts.packages = [pkgs.nerd-fonts.fira-code];

      environment.etc."tiny-dfr/config.toml".text = ''
        media_layer_default = true
        show_button_outlines = true
        enable_pixel_shift = false
        adaptive_brightness = false
        active_brightness = 1

        [styles.basic]
        height = "92%"
        margin = 12.0
        border_radius = 8.0
        background = "#333333"
        background_active = "#666666"
        foreground = "#FFFFFF"

        [styles.media]
        height = "92%"
        margin = 12.0
        border_radius = 8.0
        background = "#333333"
        background_active = "#666666"
        foreground = "#FFFFFF"
        font = "FiraCode Nerd Font"
        font_size = 30.0
        font_style = ["bold"]

        [styles.playback]
        height = "92%"
        margin = 12.0
        border_radius = 12.0
        border_width = 2.0
        border_color = "#5588FF"
        background = "#1a1a2e"
        background_active = "#3a3a5e"
        foreground = "#88BBFF"
        font = "FiraCode Nerd Font"
        font_size = 32.0
        font_style = ["bold"]

        [[primary_layer_keys]]
        text = "F1"
        action = "F1"
        style = "basic"

        [[primary_layer_keys]]
        text = "F2"
        action = "F2"
        style = "basic"

        [[primary_layer_keys]]
        text = "F3"
        action = "F3"
        style = "basic"

        [[primary_layer_keys]]
        text = "F4"
        action = "F4"
        style = "basic"

        [[primary_layer_keys]]
        text = "F5"
        action = "F5"
        style = "basic"

        [[primary_layer_keys]]
        text = "F6"
        action = "F6"
        style = "basic"

        [[primary_layer_keys]]
        text = "F7"
        action = "F7"
        style = "basic"

        [[primary_layer_keys]]
        text = "F8"
        action = "F8"
        style = "basic"

        [[primary_layer_keys]]
        text = "F9"
        action = "F9"
        style = "basic"

        [[primary_layer_keys]]
        text = "F10"
        action = "F10"
        style = "basic"

        [[primary_layer_keys]]
        text = "F11"
        action = "F11"
        style = "basic"

        [[primary_layer_keys]]
        text = "F12"
        action = "F12"
        style = "basic"

        [[primary_layer_keys]]
        text = "SysRq"
        action = "Sysrq"
        style = "basic"

        [[media_layer_keys]]
        text = "󰃞"
        action = "BrightnessDown"
        style = "media"

        [[media_layer_keys]]
        text = "󰃠"
        action = "BrightnessUp"
        style = "media"

        [[media_layer_keys]]
        text = "󰍬"
        action = "MicMute"
        style = "media"

        [[media_layer_keys]]
        text = "󰍉"
        action = "Search"
        style = "media"

        [[media_layer_keys]]
        text = "󰌏"
        action = "IllumDown"
        style = "media"

        [[media_layer_keys]]
        text = "󰌐"
        action = "IllumUp"
        style = "media"

        [[media_layer_keys]]
        text = "󰒮"
        action = "PreviousSong"
        style = "playback"
        width = 80

        [[media_layer_keys]]
        text = "󰐎"
        action = "PlayPause"
        style = "playback"
        width = 80

        [[media_layer_keys]]
        text = "󰒭"
        action = "NextSong"
        style = "playback"
        width = 80

        [[media_layer_keys]]
        text = "󰖁"
        action = "Mute"
        style = "media"

        [[media_layer_keys]]
        text = "󰕿"
        action = "VolumeDown"
        style = "media"

        [[media_layer_keys]]
        text = "󰕾"
        action = "VolumeUp"
        style = "media"

        [[media_layer_keys]]
        text = "󰹑"
        action = "SelectiveScreenshot"
        style = "media"
      '';
    };
  };
}
