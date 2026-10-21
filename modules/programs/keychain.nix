{ ... }:
{
  # ssh config, gpg, and the gpg-agent daemon with a terminal pinentry. Kept free
  # of desktop (Hyprland) deps so it works on headless hosts.
  flake.modules.homeManager.keychain =
    {
      pkgs,
      lib,
      ...
    }:
    let
      cacheTtl = 84000;
    in
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*".addKeysToAgent = "yes";
      };

      programs.gpg.enable = true;

      # Headless default: a plain ssh-agent carries the passphraseless per-host
      # key. It holds keys in RAM without re-encrypting them, so loading one needs
      # no passphrase. The laptop (keychain-desktop) turns this off and routes ssh
      # through gpg-agent instead.
      services.ssh-agent.enable = lib.mkDefault true;

      services.gpg-agent = {
        enable = true;
        # Only the laptop gates ssh behind gpg-agent (keychain-desktop sets this
        # true, for one pinentry across GPG + ssh). Servers hold no GPG keys, and
        # funnelling their passphraseless key through gpg-agent would force a
        # keystore passphrase on first outbound ssh.
        enableSshSupport = lib.mkDefault false;
        defaultCacheTtl = cacheTtl;
        maxCacheTtl = cacheTtl;
        defaultCacheTtlSsh = cacheTtl;
        maxCacheTtlSsh = cacheTtl;
        # keychain-desktop overrides this with pinentry-floating (plain
        # assignment beats mkDefault).
        pinentry.package = lib.mkDefault pkgs.pinentry-curses;
        extraConfig = ''
          allow-loopback-pinentry
        '';
      };
    };

  # Desktop override: swaps in pinentry-floating, which spawns a floating kitty
  # terminal running pinentry-curses and bridges gpg-agent's assuan protocol over
  # FIFOs. Reads config.terminal + Hyprland geometry, so it is not headless-safe.
  # Must be imported alongside the keychain base (user-desktop imports both);
  # self-importing it would duplicate allow-loopback-pinentry in gpg-agent.conf.
  flake.modules.homeManager.keychain-desktop =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      terminal = lib.getExe config.terminal;
      gaps_out = toString config.wayland.windowManager.hyprland.settings.config.general.gaps_out;
      inset = "15";
      wclass = "pinentry-floating";
      jq = lib.getExe pkgs.jq;
      stty = "${pkgs.coreutils}/bin/stty";

      # Runs in the floating terminal and bridges assuan over the two FIFOs.
      # Polls stty size on a 50 ms tick and exec's pinentry-curses after 3
      # consecutive reads agree, so curses gets the resized grid even if the
      # hyprctl resize landed before this script started sampling.
      pinentry-term = pkgs.writeShellScript "pinentry-term" ''
        last=$(${stty} size)
        stable=0
        while [ "$stable" -lt 3 ]; do
          sleep 0.05
          cur=$(${stty} size)
          if [ "$cur" = "$last" ]; then
            stable=$((stable + 1))
          else
            last=$cur
            stable=0
          fi
        done
        exec ${lib.getExe pkgs.pinentry-curses} < "$1" > "$2"
      '';

      pinentry-floating = pkgs.writeShellApplication {
        name = "pinentry-floating";
        runtimeInputs = with pkgs; [
          coreutils
          hyprland
          jq
          gnused
        ];
        text = ''
          tmpdir=$(mktemp -d /tmp/${wclass}.XXXXXX)
          mkfifo "$tmpdir/in" "$tmpdir/out"

          # Save stdin to fd 3 — backgrounded commands in scripts get /dev/null
          exec 3<&0

          # Remember cursor position to restore after pinentry closes
          cursor=$(hyprctl cursorpos -j | ${jq} -r '"x = \(.x), y = \(.y)"')
          trap 'hyprctl dispatch "hl.dsp.cursor.move({ $cursor })" > /dev/null; rm -rf "$tmpdir"' EXIT

          # Spawn floating terminal with pinentry-curses. Under the lua config
          # generator the bracketed rule prefix is gone; rules are a table now.
          pinentry_cmd="${terminal} --class ${wclass} --title GPG -o window_margin_width=3 ${pinentry-term} $tmpdir/in $tmpdir/out"
          hyprctl dispatch "hl.dsp.exec_cmd('$pinentry_cmd', { float = true, pin = true })" > /dev/null

          # Poll until the window exists (hyprland v0.54: size/move broken in inline rules)
          while ! hyprctl clients -j | ${jq} -e '.[] | select(.class == "${wclass}")' > /dev/null 2>&1; do
            sleep 0.05
          done

          # Resize, then position top-right aligned with tiled window edges.
          # hl.dsp.window.resize takes pixels, so the old 35%/21% is worked out here.
          mon_w=$(hyprctl monitors -j | ${jq} -r '.[0] | (.width  / .scale | floor)')
          mon_h=$(hyprctl monitors -j | ${jq} -r '.[0] | (.height / .scale | floor)')
          hyprctl dispatch \
            "hl.dsp.window.resize({ x = $(( mon_w * 35 / 100 )), y = $(( mon_h * 21 / 100 )), window = 'class:${wclass}' })" \
            > /dev/null
          win_w=$(hyprctl clients -j | ${jq} -r '.[] | select(.class == "${wclass}") | .size[0]')
          bar_h=$(hyprctl layers -j  | ${jq} '[.. | objects | select(.namespace == "waybar") | .h] | max')
          hyprctl dispatch \
            "hl.dsp.window.move({ x = $(( mon_w - win_w - ${gaps_out} - ${inset} )), y = $(( bar_h + ${gaps_out} + ${inset} )), window = 'class:${wclass}' })" \
            > /dev/null
          hyprctl dispatch "hl.dsp.focus({ window = 'class:${wclass}' })" > /dev/null

          # Bridge assuan protocol: rewrite ttyname so pinentry-curses uses
          # kitty's PTY (/dev/tty) instead of the caller's terminal
          sed -u 's|^OPTION ttyname=.*|OPTION ttyname=/dev/tty|' <&3 > "$tmpdir/in" &
          SED_PID=$!
          cat "$tmpdir/out"
          kill "$SED_PID" 2>/dev/null || true
        '';
      };
    in
    {
      services.gpg-agent.pinentry.package = pinentry-floating;
      # The laptop routes ssh through gpg-agent (one pinentry for GPG + ssh), so
      # the plain headless ssh-agent is off here. Plain assignments beat the base
      # mkDefaults.
      services.gpg-agent.enableSshSupport = true;
      services.ssh-agent.enable = false;
    };
}
