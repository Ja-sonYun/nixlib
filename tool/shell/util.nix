{ lib, ... }:

with lib;

{
  /**
    Helper function to convert an environment attribute set into shell export commands.

    # Input

    - `environment`: An attribute set of environment variables.

    # Output

    A string of shell commands that export each environment variable.

    # Example usage

    ```
    let
      env = {
        VAR1 = "value1";
        VAR2 = "value2";
      };
    in
      shellExports env
    ```

    This would produce the following string:

    ```
    export VAR1='value1'
    export VAR2='value2'
    ```
  */
  shellExports =
    environment:
    concatStringsSep "\n" (
      mapAttrsToList (name: value: "export ${name}=${escapeShellArg (toString value)}") environment
    );

}
