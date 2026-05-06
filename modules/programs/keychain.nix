{...}: {
  flake.modules.homeManager.keychain = {
    pkgs,
    lib,
    config,
    ...
  }: let
    terminal = lib.getExe config.terminal;
    gaps_out = toString config.wayland.windowManager.hyprland.settings.general.gaps_out;
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

    # Pinentry wrapper that spawns a floating terminal with pinentry-curses inside,
    # bridging the gpg-agent assuan protocol over named pipes (FIFOs).
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
        cursor=$(hyprctl cursorpos -j | ${jq} -r '"\(.x) \(.y)"')
        trap 'hyprctl dispatch movecursor $cursor > /dev/null; rm -rf "$tmpdir"' EXIT

        # Spawn floating terminal with pinentry-curses
        hyprctl dispatch exec "[float; pin]" \
          "${terminal} --class ${wclass} --title GPG -o window_margin_width=3 \
          ${pinentry-term} $tmpdir/in $tmpdir/out" > /dev/null

        # Poll until the window exists (hyprland v0.54: size/move broken in inline rules)
        while ! hyprctl clients -j | ${jq} -e '.[] | select(.class == "${wclass}")' > /dev/null 2>&1; do
          sleep 0.05
        done

        # Resize, then position top-right aligned with tiled window edges
        hyprctl dispatch resizewindowpixel exact 35% 21%,class:${wclass} > /dev/null
        win_w=$(hyprctl clients -j  | ${jq} -r '.[] | select(.class == "${wclass}") | .size[0]')
        mon_w=$(hyprctl monitors -j | ${jq} -r '.[0] | (.width / .scale | floor)')
        bar_h=$(hyprctl layers -j   | ${jq} '[.. | objects | select(.namespace == "waybar") | .h] | max')
        hyprctl dispatch movewindowpixel exact \
          "$(( mon_w - win_w - ${gaps_out} - ${inset} ))" \
          "$(( bar_h + ${gaps_out} + ${inset} ))",class:${wclass} > /dev/null
        hyprctl dispatch focuswindow class:${wclass} > /dev/null

        # Bridge assuan protocol: rewrite ttyname so pinentry-curses uses
        # kitty's PTY (/dev/tty) instead of the caller's terminal
        sed -u 's|^OPTION ttyname=.*|OPTION ttyname=/dev/tty|' <&3 > "$tmpdir/in" &
        SED_PID=$!
        cat "$tmpdir/out"
        kill "$SED_PID" 2>/dev/null || true
      '';
    };
  in {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*".addKeysToAgent = "yes";
    };

    services.ssh-agent.enable = true;

    programs.gpg.enable = true;

    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 84000;
      maxCacheTtl = 84000;
      pinentry.package = pinentry-floating;
      extraConfig = ''
        allow-loopback-pinentry
      '';
    };
  };
}
