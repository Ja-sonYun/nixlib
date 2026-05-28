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
  cfg = config.services.frpc;

  tomlFormat = pkgs.formats.toml { };

  runtimeConfigFile = "/run/frpc/config.toml";
in
{
  options.services.frpc = {
    enable = mkEnableOption "FRP client";

    package = mkPackageOption pkgs "frp" { };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      example = literalExpression ''
        {
          serverAddr = "frp.example.com";
          serverPort = 7000;
          auth = {
            method = "token";
            token._secret = "/run/secrets/frp-token";
          };
          proxies = [
            {
              name = "ssh";
              type = "tcp";
              localIP = "127.0.0.1";
              localPort = 22;
              remotePort = 6000;
            }
          ];
        }
      '';
      description = ''
        Raw frpc TOML settings.

        These values are written to the Nix store. To load a secret from a file
        at runtime, set the value to `{ _secret = "/path/to/file"; }`.
      '';
    };

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Extra command-line arguments passed to frpc after -c.";
    };
  };

  config = mkIf cfg.enable (
    let
      secretSettings = tool.secretSettings cfg.settings;
      agenixDependencies = secretSettings.agenixDependencies { inherit config options; };
    in
    {
      assertions = [
        {
          assertion = secretSettings.invalidSecretPaths == [ ];
          message = "services.frpc.settings contains invalid _secret values at: ${concatStringsSep ", " secretSettings.invalidSecretPaths}.";
        }
      ];

      systemd.services.frpc =
        let
          configFile = tomlFormat.generate "frpc.toml" secretSettings.value;
          commandArgs = [
            "--strict_config"
            "-c"
            runtimeConfigFile
          ]
          ++ cfg.extraArgs;
          startPreScript = pkgs.writeShellScript "frpc-start-pre" (
            secretSettings.replacementScript runtimeConfigFile
          );
        in
        {
          description = "FRP client";
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
            ExecStart = "${cfg.package}/bin/frpc ${escapeShellArgs commandArgs}";
            Restart = "on-failure";
            RuntimeDirectory = "frpc";
            RuntimeDirectoryMode = "0700";
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
