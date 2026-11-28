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
      inherit (tomlFormat) type;
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
      inherit (tool) secret;
      agenixDependencies = secret.agenixDependencies cfg.settings { inherit config options; };
    in
    {
      assertions = [
        {
          assertion = secret.invalidPaths cfg.settings == [ ];
          message = "services.frpc.settings contains invalid _secret values at: ${concatStringsSep ", " (secret.invalidPaths cfg.settings)}.";
        }
      ];

      systemd.services.frpc =
        let
          commandArgs = [
            "--strict_config"
            "-c"
            runtimeConfigFile
          ]
          ++ cfg.extraArgs;
        in
        {
          description = "FRP client";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ] ++ agenixDependencies;
          wants = [ "network-online.target" ] ++ agenixDependencies;

          serviceConfig = {
            DynamicUser = true;
            ExecStartPre = secret.installConfig cfg.settings "toml" runtimeConfigFile;
            ExecStart = "${cfg.package}/bin/frpc ${escapeShellArgs commandArgs}";
            Restart = "on-failure";
            RuntimeDirectory = "frpc";
            RuntimeDirectoryMode = "0700";
            LoadCredential = secret.credentials cfg.settings;
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
