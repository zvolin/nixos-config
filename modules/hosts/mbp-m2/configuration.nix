{ inputs, ... }:
{
  flake.modules.nixos.mbp-m2 =
    { config, pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-desktop
        ./_host/hardware-configuration.nix
        asahi
        boot-grub
        impermanence
        networking
        lan-hosts
        overlay-brightdata-mcp
        overlay-render-markdown
        overlay-tiny-dfr
        open-bambu-networking
        docker
        flatpak
        xremap
        tiny-dfr
        codex
        tailscale
        user-headless
        user-sops
        ntfy-publisher-secret
        user-desktop
      ];

      networking.hostName = "mbp-m2";

      # dialout: access to serial/USB devices.
      users.users.zwolin.extraGroups = [ "dialout" ];

      # Commit-signing identity: the laptop GPG key.
      home-manager.users.zwolin.programs.git.signing = {
        format = "openpgp";
        key = "9DD9C8FD06750734";
      };

      hardware.asahi.peripheralFirmwareDirectory =
        pkgs.runCommand "asahi-firmware-cpio"
          {
            nativeBuildInputs = [ config.hardware.asahi.pkgs.asahi-fwextract ];
          }
          ''
            mkdir -p $out
            asahi-fwextract ${./_host/firmware} $out
          '';
      system.stateVersion = "24.05";

      environment.variables.WLR_DRM_DEVICES = "/dev/dri/card0";

      services.tiny-dfr.enable = true;

      # On resume connman re-associates at the instant of wake, before the
      # brcmfmac radio has re-initialised. When it loses that race it fails its
      # two instant retries and parks the wifi service in "failure" with no
      # further retry, so wifi stays down until a manual reconnect. Its normal
      # reconnect reaches online in ~7s, so give it 10s; if it is still not up,
      # restart connman to re-run autoconnect (what a manual reconnect does,
      # but without a hardcoded SSID). Loop so a deep suspend's longer radio
      # warm-up eventually recovers too. Launched detached so it never blocks
      # the resume path, and a no-op on the resumes that reconnect on their own.
      # Apple-Silicon/brcmfmac specific, hence host-scoped rather than in the
      # shared networking aspect.
      powerManagement.resumeCommands =
        let
          recover = pkgs.writeShellScript "connman-resume-recover" ''
            for _ in $(seq 1 6); do
              sleep 10
              ${pkgs.connman}/bin/connmanctl state \
                | ${pkgs.gnugrep}/bin/grep -qE 'State = (ready|online)' && exit 0
              ${pkgs.systemd}/bin/systemctl restart connman.service
            done
          '';
        in
        "${pkgs.systemd}/bin/systemd-run --no-block ${recover}";
    };
}
