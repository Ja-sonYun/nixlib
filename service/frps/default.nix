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
      inherit (tool) secret;
      agenixDependencies = secret.agenixDependencies cfg.settings { inherit config options; };

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
          assertion = secret.invalidPaths cfg.settings == [ ];
          message = "services.frps.settings contains invalid _secret values at: ${concatStringsSep ", " (secret.invalidPaths cfg.settings)}.";
        }
      ];

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
        (optional hasBindPort bindPort) ++ singleAllowPorts
      );
      networking.firewall.allowedTCPPortRanges = mkIf cfg.openFirewall allowedPortRanges;

      systemd.services.frps =
        let
          commandArgs = [
            "--strict_config"
            "-c"
            runtimeConfigFile
          ]
          ++ cfg.extraArgs;
        in
        {
          description = "FRP server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ] ++ agenixDependencies;
          wants = agenixDependencies;

          serviceConfig = {
            DynamicUser = true;
            ExecStartPre = secret.installConfig cfg.settings "toml" runtimeConfigFile;
            ExecStart = "${cfg.package}/bin/frps ${escapeShellArgs commandArgs}";
            Restart = "on-failure";
            RuntimeDirectory = "frps";
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
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          };
        };
    }
  );
}
