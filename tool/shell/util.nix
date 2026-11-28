{
  lib,
  pkgs,
  tool,
  ...
}:

with lib;

let
  secretValue =
    mode: value:
    if tool.secret.isValidSecret value then
      "$(${tool.secret.readCommand { inherit mode; } value._secret})"
    else
      throw "A secret value must contain only a string _secret path.";

  environmentValue =
    value: if tool.secret.isSecret value then secretValue "empty" value else toString value;

  shellExportsWith =
    {
      mode ? "empty",
      keepExisting ? false,
    }:
    environment:
    concatStringsSep "\n" (
      mapAttrsToList (
        name: value:
        let
          export =
            if tool.secret.isSecret value then
              ''
                ${name}="${secretValue mode value}" || exit "$?"
                export ${name}
              ''
            else
              "export ${name}=${escapeShellArg (toString value)}";
        in
        if keepExisting then
          ''
            if [ -z "''${${name}+x}" ]; then
              ${export}
            fi
          ''
        else
          export
      ) environment
    );
in
{
  /**
    Render a shell-expanded value for options such as home.sessionVariables.
    Secret paths are shell-expanded and read at runtime; unreadable files expand
    to an empty string.
    Invalid _secret forms are rejected. The result is not shell-quoted; use
    shellExports when emitting export commands.
  */
  inherit environmentValue shellExportsWith;

  /**
    Generate shell exports for literal values and runtime _secret file reads.
  */
  shellExports = shellExportsWith { };

  wrapSecretEnv =
    {
      name,
      command,
      args ? [ ],
      env ? { },
    }:
    let
      secrets = filterAttrs (_: tool.secret.isSecret) env;
    in
    optionalAttrs (secrets != { }) {
      command = toString (
        pkgs.writeShellScript "${name}-env-wrapper" ''
          ${shellExportsWith { mode = "wait"; } secrets}
          exec ${escapeShellArgs ([ command ] ++ args)} "$@"
        ''
      );
      args = [ ];
      env = filterAttrs (_: value: !tool.secret.isSecret value) env;
    };
}
