{ ... }:
{
  flake.modules.homeManager.kitty =
    { ... }:
    {
      programs.kitty = {
        enable = true;
        settings = {
          scrollback_lines = 20000;
          enable_audio_bell = false;
          # disable all terminal-initiated notifications
          filter_notification = "all";
          # don't ask for confirmation to close window
          confirm_os_window_close = 0;
          window_padding_width = 1;
          # Under a tiling WM the compositor owns window geometry, so there is
          # nothing useful to remember — and since kitty 0.49 this also restores
          # the maximized state, which Hyprland honours as a fullscreen request
          # that breaks tiling for every new window. "no" stops kitty saving or
          # restoring that state (the state file lives under /home and survives
          # impermanence, so a persisted value would otherwise linger).
          remember_window_size = "no";
          # yaay, cursor trail
          cursor_trail = 2;
          cursor_trail_decay = "0.05 0.2";
          cursor_trail_start_threshold = 4;
        };
        keybindings = {
          "ctrl+shift+t" = "no_op";
        };
      };
    };
}
