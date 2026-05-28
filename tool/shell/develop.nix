{ pkgs, lib, ... }:

with lib;

let
  getShellAttrs =
    shell:
    shell.passthru.shellAttrs
      or (throw "concatShells only supports shells created with this shell library's mkShell.");
in
rec {
  /**
    Create a Nix shell with the specified attributes.

    # Inputs

    - `name`: The name of the shell (default: "nix-shell").
    - `packages`: A list of packages to include in the shell (default: empty list).
    - `env`: An attribute set of environment variables to set in the shell (default: empty set).
    - `shellHook`: A string of shell commands to run when the shell starts (default: empty string).
    - `noCC`: If true, use `mkShellNoCC` to create the shell, which does not include a C compiler (default: false).
    - `passthru`: An attribute set of additional attributes to pass through to the underlying shell derivation (default: empty set).
    - `...`: Any additional attributes supported by `mkShell` can also be included and will be passed through.

    # Output

    A Nix shell derivation with the specified attributes.
    We can concatenate multiple shells together using `concatShells`, which will merge their packages, environment variables, and shell hooks.

    # Example usage

    ```
    myShell = mkShell {
      name = "my-shell";
      packages = [ pkgs.git pkgs.nodejs ];
      env = {
        MY_VAR = "value";
      };
      shellHook = "echo Welcome to my shell!";
    };
    ```
  */
  mkShell =
    {
      name ? "nix-shell",
      packages ? [ ],
      env ? { },
      shellHook ? "",
      noCC ? false,
      passthru ? { },
      ...
    }@attrs:
    let
      shellAttrs = {
        inherit
          name
          packages
          env
          shellHook
          ;
      };
      drvAttrs = removeAttrs attrs [
        "noCC"
        "passthru"
      ];
      mkShellPackage = if noCC then pkgs.mkShellNoCC else pkgs.mkShell;
    in
    mkShellPackage (
      drvAttrs
      // {
        passthru = passthru // {
          inherit shellAttrs;
        };
      }
    );

  /**
    Concatenate multiple shells together, merging their packages, environment variables, and shell hooks.

    # Inputs

    - `name`: The name of the resulting shell (default: "shell").
    - `shells`: A list of shells to concatenate. Each shell must be created with `mkShell` and have its attributes available in `passthru.shellAttrs`.
    - `packages`: Additional packages to include in the resulting shell (default: empty list).
    - `env`: Additional environment variables to set in the resulting shell (default: empty set).
    - `shellHook`: Additional shell commands to run when the resulting shell starts (default: empty string).

    # Output

    A Nix shell derivation that combines the attributes of all input shells and the additional attributes specified.

    # Example usage

    ```
    shell1 = mkShell {
      name = "shell1";
      packages = [ pkgs.git ];
      env = {
        SHELL1_VAR = "value1";
      };
      shellHook = "echo This is shell 1!";
    };
    shell2 = mkShell {
      name = "shell2";
      packages = [ pkgs.nodejs ];
      env = {
        SHELL2_VAR = "value2";
      };
      shellHook = "echo This is shell 2!";
    };

    combinedShell = concatShells {
      name = "combined-shell";
      shells = [ shell1 shell2 ];
      packages = [ pkgs.curl ];
      shellHook = "echo This is a combined shell!";
    };
    ```
  */
  concatShells =
    {
      name ? "shell",
      shells,
      packages ? [ ],
      env ? { },
      shellHook ? "",
    }:
    let
      shellAttrs = map getShellAttrs shells;
      mergedPackages = concatLists (map (attrs: attrs.packages or [ ]) shellAttrs) ++ packages;
      mergedEnv = foldl' (acc: attrs: acc // (attrs.env or { })) { } shellAttrs // env;
      mergedShellHook = concatStringsSep "\n" (
        (map (attrs: attrs.shellHook or "") shellAttrs) ++ [ shellHook ]
      );
    in
    mkShell {
      inherit name;
      packages = mergedPackages;
      env = mergedEnv;
      shellHook = mergedShellHook;
    };
}
