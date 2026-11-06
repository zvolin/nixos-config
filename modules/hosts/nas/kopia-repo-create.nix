{ inputs, ... }:
{
  perSystem =
    {
      system,
      lib,
      pkgs,
      ...
    }:
    let
      settings = import ./_kopia-settings.nix;

      # Create-only: fixes the irreversible compliance retention floor, enables object-lock
      # extension, sets the maintenance owner, and stamps the staleness baseline. Reads creds
      # from /run/secrets as root; run on nas only after the password deploys and object-lock
      # extension is validated on a throwaway repo.
      createApp = pkgs.writeShellApplication {
        name = "create-kopia-repo";
        runtimeInputs = [
          pkgs.kopia
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail
          secret_dir=/run/secrets/backup
          KOPIA_PASSWORD="$(cat "$secret_dir/kopia-repository-password")"
          b2_key="$(cat "$secret_dir/b2-application-key")"
          export KOPIA_PASSWORD
          mkdir -p ${settings.stateDir} ${settings.cacheDir}
          # --cache-directory is a create-only flag, not global; set it on create, and the
          # status guard and maintenance set read the cache from the config.
          kopia="kopia --config-file=${settings.configFile}"
          if $kopia repository status >/dev/null 2>&1; then
            echo "create-kopia-repo: already connected to ${settings.configFile}; nothing to create." >&2
            exit 0
          fi
          $kopia repository create s3 \
            --bucket=${settings.bucket} \
            --endpoint=${settings.endpoint} \
            --region=${settings.region} \
            --prefix=${settings.prefix} \
            --access-key=${settings.accessKeyId} \
            --secret-access-key="$b2_key" \
            --cache-directory=${settings.cacheDir} \
            --retention-mode=COMPLIANCE \
            --retention-period=${toString settings.retentionPeriodDays}d \
            --enable-actions
          $kopia maintenance set \
            --owner=${settings.maintenanceOwner} --extend-object-locks=true
          touch ${settings.maintenanceStamp}
          echo "create-kopia-repo: repository created and object-lock extension enabled." >&2
        '';
      };
    in
    lib.optionalAttrs (system == "x86_64-linux") {
      apps.create-kopia-repo = {
        type = "app";
        program = lib.getExe createApp;
        meta.description = "Create the nas Kopia compliance-WORM B2 repository (run on nas after the repository password is deployed and object-lock extension is validated).";
      };
      packages.create-kopia-repo = createApp;
    };
}
