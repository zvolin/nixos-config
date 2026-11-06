{ lib, ... }:
{
  # Warns at switch time (not every eval, like build-time `warnings`) when a resource is
  # absent, instead of failing the switch or silently skipping like `ConditionPathExists`.
  flake.modules.nixos.provisioning-guard =
    { config, lib, ... }:
    {
      options.homelab.provisioningGuards = lib.mkOption {
        default = { };
        description = "Named activation-time provisioning guards; each warns (never fails) when its check is non-zero.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              check = lib.mkOption {
                type = lib.types.str;
                description = "Shell command run at activation; non-zero means not provisioned.";
              };
              runbook = lib.mkOption {
                type = lib.types.str;
                description = "Runbook path printed in the warning.";
              };
            };
          }
        );
      };

      config = {
        system.activationScripts = lib.mapAttrs' (
          name: guard:
          lib.nameValuePair "provisioningGuard-${name}" {
            text = ''
              if ! ( ${guard.check} ) >/dev/null 2>&1; then
                echo "⚠ ${name} not provisioned — see ${guard.runbook}" >&2
              fi
            '';
          }
        ) config.homelab.provisioningGuards;
      };
    };
}
