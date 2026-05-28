{
  config,
  lib,
  options,
  pkgs,
  tool,
  ...
}:

with lib;

let
  cfg = config.services.cliproxyapi;

  yamlFormat = pkgs.formats.yaml { };

  settings = recursiveUpdate {
    host = "127.0.0.1";
    port = 8317;
    auth-dir = "/var/lib/cliproxyapi/auth";
    logging-to-file = false;
    remote-management = {
      allow-remote = false;
      disable-control-panel = true;
    };
  } cfg.settings;

  runtimeConfigFile = "/run/cliproxyapi/config.yaml";
in
{
  options.services.cliproxyapi = {
    enable = mkEnableOption "CLIProxyAPI server";

    package = mkPackageOption pkgs "CLIProxyAPI" {
      default = [ "cliproxyapi" ];
    };

    settings = mkOption {
      type = yamlFormat.type;
      default = { };
      example = literalExpression ''
        {
          port = 8317;
          api-keys = [
            { _secret = "/run/secrets/cliproxyapi-client-key"; }
          ];
          remote-management.disable-control-panel = false;
          openai-compatibility = [
            {
              name = "openrouter";
              base-url = "https://openrouter.ai/api/v1";
              api-key-entries = [
                { api-key._secret = "/run/secrets/cliproxyapi-openrouter-key"; }
              ];
            }
          ];
        }
      '';
      description = ''
        Raw CLIProxyAPI YAML settings.

        These values are written to the Nix store. To load a secret from a file
        at runtime, set the value to `{ _secret = "/path/to/file"; }`.
      '';
    };

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Extra command-line arguments passed to CLIProxyAPI before --config.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the configured CLIProxyAPI TCP port in the firewall.";
    };
  };

  config = mkIf cfg.enable (
    let
      secretSettings = tool.secretSettings settings;
      agenixDependencies = secretSettings.agenixDependencies { inherit config options; };
    in
    {
      assertions = [
        {
          assertion = secretSettings.invalidSecretPaths == [ ];
          message = "services.cliproxyapi.settings contains invalid _secret values at: ${concatStringsSep ", " secretSettings.invalidSecretPaths}.";
        }
      ];

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ settings.port ];

      systemd.services.cliproxyapi =
        let
          configFile = yamlFormat.generate "cliproxyapi.yaml" secretSettings.value;
          commandArgs = cfg.extraArgs ++ [
            "--config"
            runtimeConfigFile
          ];
          startPreScript = pkgs.writeShellScript "cliproxyapi-start-pre" (
            secretSettings.replacementScript runtimeConfigFile
          );
        in
        {
          description = "CLIProxyAPI server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ] ++ agenixDependencies;
          wants = [ "network-online.target" ] ++ agenixDependencies;
          path = with pkgs; [ replace-secret ];
          restartTriggers = secretSettings.restartTriggers;

          serviceConfig = {
            DynamicUser = true;
            ExecStartPre = [
              "${pkgs.coreutils}/bin/install -m 600 ${configFile} ${runtimeConfigFile}"
            ]
            ++ optional (secretSettings.secretPaths != [ ]) startPreScript;
            ExecStart = "${cfg.package}/bin/cliproxyapi ${escapeShellArgs commandArgs}";
            Restart = "on-failure";
            RuntimeDirectory = "cliproxyapi";
            RuntimeDirectoryMode = "0700";
            StateDirectory = "cliproxyapi";
            StateDirectoryMode = "0700";
            LoadCredential = secretSettings.credentials;
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            SystemCallArchitectures = "native";
          };
        };
    }
  );
}
