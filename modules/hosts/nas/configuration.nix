{ inputs, ... }:
{
  flake.modules.nixos.nas =
    { ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-cli
        nas-disko
        ./_host/hardware.nix
        networking-wired
        lan-hosts
        headless-host
        user-headless
        user-sops
        nut-server
        # codex's system arm (/etc/codex config.toml); claude is HM-only.
        codex
        # brightdata-mcp is interpolated by the mcp HM module (via ai-headless);
        # an HM module cannot apply an overlay, so the host imports it.
        overlay-brightdata-mcp
        overlay-render-markdown
      ];

      networking.hostName = "nas";

      # GUI-free AI/agent set on top of the user-headless base. nas does not use
      # user-desktop.
      home-manager.users.zwolin.imports = [ inputs.self.modules.homeManager.ai-headless ];

      system.stateVersion = "26.11";
    };
}
