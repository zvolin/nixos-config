# One module for the whole Bambu-printer concern. It intentionally folds four
# aspects into a single file — the SSDP firewall (NixOS), the shared OBN plugin
# internals, and both slicer modules (Bambu Studio + OrcaSlicer, Home Manager) —
# because they are two consumers of ONE concern: the same printer protocol over
# the same OBN plugin. Keeping them together gives a single OBN version/hash pin
# and one ABI guard both slicers share, and removes a real coupling: the SSDP
# firewall port used to be registered under `bambu-studio`, so Orca (a Home
# Manager module, which cannot open a firewall port) would have silently
# depended on Studio being imported. The host now imports the firewall aspect in
# its own right ("this host has a Bambu printer"); neither slicer owns the port.
# The file is already ~320 lines but stays single-file for the shared-OBN-pin
# cohesion. Split into an open-bambu-networking/ directory when a third slicer or
# substantially more prose lands.
{ inputs, ... }:
let
  # Shared OBN pin for both slicers. Bump: change obnVersion + obnHash, then
  # re-check BOTH ABI windows (studioAbi in the bambu-studio module, orcaAbi in
  # the orca-slicer module) against what the new tarball ships.
  # Hash: nix store prefetch-file --hash-type sha256 <url>
  obnVersion = "v2.1.0";
  obnHash = "sha256-bzxpIeUTDv2SJCD5Fi1kL8KybFqd520lbDSo/zXd4Xo=";
  obnUrl = "https://github.com/ClusterM/open-bamboo-networking/releases/download/${obnVersion}/obn-linux-aarch64.tar.gz";

  # Shared OBN internals, parameterized by pkgs (flake-parts exposes no pkgs at
  # file scope; each Home Manager module passes its own). Both slicers run the
  # same nixpkgs, so `obnLib pkgs` yields identical derivations.
  obnLib =
    pkgs:
    let
      obnDist = pkgs.fetchurl {
        url = obnUrl;
        hash = obnHash;
      };

      # Unpack to store; --strip-components=1 drops the top dir so paths are lib/<abi>/….
      obnPlugins = pkgs.runCommand "obn-plugins-${obnVersion}" { } ''
        mkdir -p "$out"
        tar -xzf ${obnDist} -C "$out" --strip-components=1
      '';

      # Build-time ABI guard: fail `nix build` (not the user's switch) if the
      # requested ABI is missing from the tarball. A bare path concat would build
      # green and blow up at activation, which the agent cannot run. Copies just
      # the matched dir, so activation references an already-checked store path.
      mkAbiDir =
        abi:
        pkgs.runCommand "obn-abi-${abi}" { } ''
          src="${obnPlugins}/lib/${abi}"
          if [ ! -d "$src" ]; then
            echo "OBN ${obnVersion} ships no ABI set lib/${abi}." >&2
            echo "Available: $(ls ${obnPlugins}/lib | tr '\n' ' ')" >&2
            echo "Align the ABI with the installed slicer version, or bump OBN." >&2
            exit 1
          fi
          cp -r "$src" "$out"
        '';

      # Idempotent conf patcher. Usage: python3 <script> <conf-path> key=value ...
      # Sets each key under the top-level "app" object and preserves the trailing
      # MD5 line. Adapted from OBN install.sh. Keys apply in argv order (matters
      # only when adding a new key, which appends).
      confPatcher = pkgs.writeText "patch-bambu-conf.py" ''
        import json, re, shutil, sys

        conf_path = sys.argv[1]
        conf_name = conf_path.rsplit("/", 1)[-1]
        pairs = [arg.split("=", 1) for arg in sys.argv[2:]]

        with open(conf_path) as f:
            raw = f.read()

        raw_json = re.sub(r'[\r\n]+# MD5 checksum[^\r\n]*[\r\n]*$', "", raw)
        try:
            conf = json.loads(raw_json)
        except json.JSONDecodeError:
            print(f"[warn] cannot parse {conf_path}, skipping", file=sys.stderr)
            sys.exit(0)

        if not isinstance(conf.get("app"), dict):
            print(f"[warn] no 'app' object in {conf_path}, skipping", file=sys.stderr)
            sys.exit(0)

        changed = False
        for key, val in pairs:
            if conf["app"].get(key) != val:
                conf["app"][key] = val
                changed = True

        if not changed:
            print(f"[info] {conf_name} already patched")
            sys.exit(0)

        shutil.copy2(conf_path, conf_path + ".obn-bak")
        with open(conf_path, "w") as f:
            f.write(json.dumps(conf, indent=4, ensure_ascii=False))
            f.write("\n# MD5 checksum 00000000000000000000000000000000\n")
        print(f"[info] patched {conf_name}")
      '';
    in
    {
      inherit obnPlugins mkAbiDir confPatcher;
    };
in
{
  # NixOS side: the printer announces itself via SSDP NOTIFY to UDP 2021, and
  # OBN listens to learn the LAN IP (feeds discovery, the print path, and the
  # camera). The default firewall drops inbound 2021, killing LAN discovery. Scope
  # to Wi-Fi so 2021 stays closed on tailscale0. The HOST imports this directly
  # — not via either slicer — so neither slicer owns the port. wlan0 is inherited
  # from the working Studio config, where LAN discovery already works.
  flake.modules.nixos.open-bambu-networking = {
    networking.firewall.interfaces."wlan0".allowedUDPPorts = [ 2021 ];
  };

  flake.modules.homeManager.bambu-studio =
    { pkgs, lib, ... }:
    let
      inherit (obnLib pkgs) mkAbiDir confPatcher;

      appId = "com.bambulab.BambuStudio";
      clientName = "BambuStudio";

      # ABI dir matching the pinned Studio flatpak (2.8.2.x -> v02.08.02). Re-check
      # the installed Studio version (`version` key in BambuStudio.conf) on every
      # Studio bump; the tarball also ships v02.08.03.
      studioAbi = "v02.08.02";
      studioAbiDir = mkAbiDir studioAbi;

      # OBN config (secret-free). cloud_print=lan_only: the cloud task API rejects
      # this aarch64 platform with HTTP 403, so route over LAN. Do NOT set
      # override_lan_ip: it short-circuits SSDP discovery, which learns the LAN IP.
      obnConf = pkgs.writeText "obn.conf" ''
        block_cloud = 0
        client_name = ${clientName}
        cloud_print = lan_only
      '';
    in
    {
      imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

      services.flatpak = {
        enable = true;
        update.auto.enable = false;
        remotes = [
          {
            name = "flathub";
            location = "https://flathub.org/repo/flathub.flatpakrepo";
          }
        ];
        packages = [
          {
            appId = appId;
            origin = "flathub";
            # Byte-exact pin to Studio 2.8.2.61 (ABI v02.08.02, matches studioAbi).
            # Re-capture on a deliberate bump and re-check the OBN ABI window:
            #   flatpak --user remote-info --log flathub com.bambulab.BambuStudio
            commit = "fa17d48b6e2a3bd367c8a534a651826a5b14b23477d69d823471a215aeda60da";
          }
        ];

        # Pair with hyprland's force_zero_scaling: GTK/XWayland apps scale themselves.
        # GDK_SCALE=1 is crisp (=2 clips panels). `global` covers all flatpaks.
        overrides.settings.global.Environment.GDK_SCALE = "1";
      };

      # OBN plugin set + config. Idempotent: the app dir may not exist before
      # Studio's first launch, so mkdir -p and skip the (app-owned) BambuStudio.conf
      # patch until Studio creates it. Operational: OBN re-pins on updates
      # (obnVersion above); on cert rotation printing fails with err_code 84033543
      # -> re-extract PEMs (spec Appendix A), no Nix rebuild; interim/fallback is
      # block_cloud=1 + LAN-Only (Handy pauses).
      home.activation.bambuStudioObn = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dataDir="$HOME/.var/app/${appId}/config/${clientName}"
        pluginDir="$dataDir/plugins"
        otaDir="$dataDir/ota/plugins"

        run mkdir -p "$pluginDir" "$otaDir"

        for so in libbambu_networking.so libBambuSource.so liblive555.so; do
          run install -m0644 "${studioAbiDir}/$so" "$pluginDir/$so"
        done
        run install -m0644 "${studioAbiDir}/network_plugins.json" "$otaDir/network_plugins.json"

        run install -m0644 ${obnConf} "$dataDir/obn.conf"

        if ${pkgs.procps}/bin/pgrep -f ${appId} >/dev/null 2>&1; then
          warnEcho "Bambu Studio is running — skipping BambuStudio.conf patch (Studio rewrites the conf on exit and would revert it). Quit Studio and rebuild."
        elif [ -f "$dataDir/BambuStudio.conf" ]; then
          run ${pkgs.python3.interpreter} ${confPatcher} "$dataDir/BambuStudio.conf" installed_networking=1 update_network_plugin=false
        else
          warnEcho "BambuStudio.conf absent — launch Studio once, then rebuild to patch it."
        fi

        # Cert PEMs: copy from /persist slot only when populated. Empty slot -> skip
        # -> interim LAN mode (secret-free) until certs land. PEMs never enter git
        # or the Nix store.
        secretSlot="/persist/users/zwolin/bambu"
        for pem in slicer_cert slicer_key slicer_crl; do
          if [ -f "$secretSlot/$pem.pem" ]; then
            run install -m0600 "$secretSlot/$pem.pem" "$dataDir/$pem.pem"
          fi
        done
      '';
    };

  flake.modules.homeManager.orca-slicer =
    { pkgs, lib, ... }:
    let
      inherit (obnLib pkgs) mkAbiDir confPatcher;

      # ABI dir Orca 2.4.2 loads (confirmed in T2 Step 1). pluginVer is the ABI
      # number plus OBN's ".99" suffix, used as the on-disk plugin filename suffix
      # and as network_plugin_version in OrcaSlicer.conf.
      orcaAbi = "v02.03.00";
      pluginVer = "02.03.00.99";

      # Native nixpkgs Orca is not a flatpak/FHS runtime: wrapGAppsHook3 sets
      # LD_LIBRARY_PATH to just $out/lib + glew, and there is no host /usr/lib.
      # OBN's prebuilt .so's have nothing to resolve their NEEDED libs against and
      # would silently fail to dlopen (flatpak Studio sidesteps this). Run
      # autoPatchelfHook over the injected blobs so their deps bind to the Nix
      # store. This derivation is also the build-time runtime-linking gate (T2 Step
      # 1b): if a NEEDED lib is missing from buildInputs, `nix build` fails at
      # agent-checkable time naming the missing lib, instead of the plugin silently
      # not loading at runtime. buildInputs is a starting set — add whatever
      # autoPatchelf reports missing. NOTE: this wraps only the Orca blobs; Studio's
      # mkAbiDir output is untouched (flatpak resolves its blobs inside the sandbox),
      # so T1's Studio output-identity holds.
      orcaAbiDir = pkgs.stdenv.mkDerivation {
        name = "obn-abi-${orcaAbi}-patched";
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [
          pkgs.stdenv.cc.cc.lib # libstdc++, libgcc_s
          pkgs.openssl # libssl, libcrypto
          pkgs.curl
          pkgs.glib
          pkgs.zlib
        ];
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -r ${mkAbiDir orcaAbi}/. "$out"/
          chmod -R u+w "$out"
          runHook postInstall
        '';
      };

      # OBN config, mirroring Studio's proven values. mqtt_keep_connection=1 because
      # Orca tears down MQTT after each print — matters on the single-slot P1S.
      # client_name=BambuStudio: the cloud refuses the real client name, so both
      # slicers pose as Studio. block_cloud=0 required so a cloud-bound printer
      # (which only reports online through the cloud tunnel) stays visible over LAN
      # — the M2 chase depends on this. Do NOT set override_lan_ip: it short-circuits
      # SSDP discovery.
      obnConf = pkgs.writeText "obn.conf" ''
        block_cloud = 0
        client_name = BambuStudio
        cloud_print = lan_only
        mqtt_keep_connection = 1
      '';

      # Minimal valid seed for the first-ever switch, before Orca creates its own
      # OrcaSlicer.conf. Carries an empty "app" object so confPatcher can add the
      # plugin keys. This fixes the first-switch ordering: Orca writes the conf on
      # first launch, after activation, so a skip-if-absent branch would never
      # register the plugin until a second switch.
      orcaConfSeed = pkgs.writeText "OrcaSlicer.conf.seed" ''
        {
            "app": {}
        }
      '';
    in
    {
      home.packages = [ pkgs.orca-slicer ];

      # OBN plugin set + config for Orca. Reimplements OBN install.sh's Orca path
      # declaratively. Idempotent; the app dir may not exist before first launch.
      home.activation.orcaSlicerObn = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dataDir="$HOME/.config/OrcaSlicer"
        pluginDir="$dataDir/plugins"

        run mkdir -p "$pluginDir"

        # OBN's Orca layout: the networking .so is version-suffixed; the other two
        # install as-is. All 0644.
        run install -m0644 "${orcaAbiDir}/libbambu_networking.so" "$pluginDir/libbambu_networking_${pluginVer}.so"
        for so in libBambuSource.so liblive555.so; do
          run install -m0644 "${orcaAbiDir}/$so" "$pluginDir/$so"
        done

        run install -m0644 ${obnConf} "$dataDir/obn.conf"

        # Create-then-patch OrcaSlicer.conf. If absent (first switch), seed a
        # minimal valid conf, then patch it so the plugin registers immediately.
        # If Orca is running, skip: Orca rewrites the conf on exit and would
        # revert the patch.
        confFile="$dataDir/OrcaSlicer.conf"
        if ${pkgs.procps}/bin/pgrep -f orca-slicer >/dev/null 2>&1; then
          warnEcho "OrcaSlicer is running — skipping OrcaSlicer.conf patch (Orca rewrites the conf on exit and would revert it). Quit Orca and rebuild."
        else
          if [ ! -f "$confFile" ]; then
            run install -m0644 ${orcaConfSeed} "$confFile"
          fi
          run ${pkgs.python3.interpreter} ${confPatcher} "$confFile" network_plugin_version=${pluginVer} installed_networking=1 network_plugin_remind_later=true
        fi

        # Cert PEMs drive OBN's secured-printer signing path (the M2 chase input).
        # Copy from the /persist slot at 0600 only when populated; empty slot ->
        # skip -> secret-free build. PEMs never enter git or the Nix store.
        secretSlot="/persist/users/zwolin/bambu"
        for pem in slicer_cert slicer_key slicer_crl; do
          if [ -f "$secretSlot/$pem.pem" ]; then
            run install -m0600 "$secretSlot/$pem.pem" "$dataDir/$pem.pem"
          fi
        done
      '';
    };
}
