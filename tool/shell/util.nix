{ lib, tool, ... }:

with lib;

let
  environmentValue =
    value:
    if tool.secretValue.isSecret value then
      if tool.secretValue.isValidSecret value then
        "$(cat -- \"${value._secret}\" 2>/dev/null || echo '')"
      else
        throw "A secret value must contain only a string _secret path."
    else
      toString value;
in
{
  /**
    Render a shell-expanded value for options such as home.sessionVariables.
    Secret paths are shell-expanded and read at runtime; unreadable files expand
    to an empty string.
    Invalid _secret forms are rejected. The result is not shell-quoted; use
    shellExports when emitting export commands.
  */
  inherit environmentValue;

  /**
    Generate shell exports for literal values and runtime _secret file reads.
  */
  shellExports =
    environment:
    concatStringsSep "\n" (
      mapAttrsToList (
        name: value:
        "export ${name}=${
          if tool.secretValue.isSecret value then
            ''"${environmentValue value}"''
          else
            escapeShellArg (environmentValue value)
        }"
      ) environment
    );

}
