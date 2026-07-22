{ ... }:
{
  flake.modules.nixos.tailscale = {
    services.tailscale.enable = true;

    # tailscaled keeps node identity and `tailscale serve` config under
    # /var/lib/tailscale, which the root-wipe (impermanence) would erase every
    # boot. Bind-mount it from /persist so the node stays authenticated.
    #
    # It has to be a bind mount, not a tmpfiles symlink (the greetd pattern):
    # the upstream unit sets StateDirectory=tailscale, and systemd refuses to
    # set up a StateDirectory whose path is a symlink -- it fails with ELOOP
    # ("Too many levels of symbolic links") before tailscaled starts. greetd's
    # cache dir has no StateDirectory, so a symlink is fine there but not here.
    # A bind mount makes /var/lib/tailscale a real directory backed by
    # /persist, which StateDirectory accepts. systemd creates the mountpoint on
    # boot, and the persisted source below survives the wipe.
    systemd.tmpfiles.settings."10-tailscale"."/persist/var/lib/tailscale".d = {
      user = "root";
      group = "root";
      mode = "0700";
    };

    fileSystems."/var/lib/tailscale" = {
      device = "/persist/var/lib/tailscale";
      fsType = "none";
      options = [ "bind" ];
    };
  };
}
