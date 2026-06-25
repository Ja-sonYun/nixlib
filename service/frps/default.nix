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
  cfg = config.services.frps;

  tomlFormat = pkgs.formats.toml { };

  runtimeConfigFile = "/run/frps/config.toml";
in
{
  options.services.frps = {
    enable = mkEnableOption "FRP server";

    package = mkPackageOption pkgs "frp" { };

    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      example = literalExpression ''
        {
          bindAddr = "0.0.0.0";
          bindPort = 7000;
          auth = {
            method = "token";
            token._secret = "/run/secrets/frp-token";
          };
        }
      '';
      description = ''
        Raw frps TOML settings.

        These values are written to the Nix store. To load a secret from a file
        at runtime, set the value to `{ _secret = "/path/to/file"; }`.
      '';
    };

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Extra command-line arguments passed to frps after -c.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open the configured frps bind and allowed TCP ports in the firewall.

        This adds {option}`services.frps.settings.bindPort` and
        {option}`services.frps.settings.allowPorts` to the firewall.
      '';
    };
  };

  config = mkIf cfg.enable (
    let
      secretSettings = tool.secretSettings cfg.settings;
      agenixDependencies = secretSettings.agenixDependencies { inherit config options; };

      bindPort = cfg.settings.bindPort or null;
      hasBindPort = builtins.isInt bindPort;
      allowPorts = cfg.settings.allowPorts or [ ];
      singleAllowPorts = map (port: port.single) (filter (port: port ? single) allowPorts);
      allowedPortRanges = map (port: {
        from = port.start;
        to = port.end;
      }) (filter (port: !(port ? single)) allowPorts);
    in
    {
      assertions = [
        {
          assertion = !cfg.openFirewall || hasBindPort;
          message = "services.frps.openFirewall requires services.frps.settings.bindPort to be an integer.";
        }
        {
          assertion = secretSettings.invalidSecretPaths == [ ];
          message = "services.frps.settings contains invalid _secret values at: ${concatStringsSep ", " secretSettings.invalidSecretPaths}.";
        }
      ];

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
        (optional hasBindPort bindPort) ++ singleAllowPorts
      );
      networking.firewall.allowedTCPPortRanges = mkIf cfg.openFirewall allowedPortRanges;

      systemd.services.frps =
        let
          configFile = tomlFormat.generate "frps.toml" secretSettings.value;
          commandArgs = [
            "--strict_config"
            "-c"
            runtimeConfigFile
          ]
          ++ cfg.extraArgs;
          startPreScript = pkgs.writeShellScript "frps-start-pre" (
            secretSettings.replacementScript runtimeConfigFile
          );
        in
        {
          description = "FRP server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ] ++ agenixDependencies;
          wants = agenixDependencies;
          path = with pkgs; [ replace-secret ];
          inherit (secretSettings) restartTriggers;

          serviceConfig = {
            DynamicUser = true;
            ExecStartPre = [
              "${pkgs.coreutils}/bin/install -m 600 ${configFile} ${runtimeConfigFile}"
            ]
            ++ optional (secretSettings.secretPaths != [ ]) startPreScript;
            ExecStart = "${cfg.package}/bin/frps ${escapeShellArgs commandArgs}";
            Restart = "on-failure";
            RuntimeDirectory = "frps";
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
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          };
        };
    }
  );
}
