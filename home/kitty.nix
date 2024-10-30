{ ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      scrollback_lines = 20000;
      enable_audio_bell = false;
      # don't ask for confirmation to close window
      confirm_os_window_close = 0;
      window_padding_width = 1;
      # yaay, cursor trail
      cursor_trail = 2;
      cursor_trail_decay = "0.05 0.2";
      cursor_trail_start_threshold = 4;
    };
  };
}
