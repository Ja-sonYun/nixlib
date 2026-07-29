{
  description = "A collection of nix utilities";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      commandFactory = import ./command;
      toolFactory = import ./tool;
      serviceModules =
        _:
        let
          serviceFactory = import ./service;
          service = serviceFactory { inherit toolFactory; };
        in
        {
          imports = builtins.attrValues service;
        };
      packageFactory = import ./pkg;
      overlays = import ./overlay {
        inherit commandFactory packageFactory toolFactory;
        nixpkgsLib = nixpkgs.lib;
      };
    in
    {
      inherit
        overlays
        systems
        serviceModules
        ;

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          command = commandFactory {
            inherit pkgs;
            inherit (pkgs) lib;
          };
          commandHookOriginal =
            (pkgs.writeShellScriptBin "example" ''
              printf 'original'
              printf ' <%s>' "$@"
            '').overrideAttrs
              (_: {
                version = "1.2.3";
              });
          commandHookPackage = command.hook {
            package = commandHookOriginal;
            binary = "example";
            hooks = [
              {
                path = [ "config" ];
                command = ''
                  printf 'short'
                  printf ' <%s>' "$@"
                '';
              }
              {
                path = [
                  "config"
                  "set"
                ];
                command = ''
                  printf 'long'
                  printf ' <%s>' "$@"
                '';
              }
              {
                path = [
                  "mcp"
                  "add"
                ];
                matchAnywhere = true;
                command = ''
                  printf 'anywhere'
                  printf ' <%s>' "$@"
                '';
              }
              {
                path = [ "commit" ];
                flag = "-g";
                command = ''
                  printf 'flag <%s>' "$COMMAND_HOOK_FLAG_INDEX"
                  printf ' <%s>' "$@"
                '';
              }
              {
                path = [ "delegate" ];
                command = ''
                  command_hook_original from-hook "$@"
                '';
              }
              {
                path = [ "custom" ];
                help = "custom help";
                command = "exit 42";
              }
            ];
          };
          commandHookVersionlessPackage = command.hook {
            package = pkgs.writeShellScriptBin "versionless" "exit 0";
            binary = "versionless";
          };
          statixConfig = (pkgs.formats.toml { }).generate "statix.toml" {
            disabled = [ "repeated_keys" ];
          };
        in
        {
          command-hook =
            assert commandHookPackage.version == "1.2.3";
            assert !(commandHookVersionlessPackage ? version);
            pkgs.runCommand "command-hook-test" { } ''
              test "$(${commandHookPackage}/bin/example config set key value)" = "long <key> <value>"
              test "$(${commandHookPackage}/bin/example config key value)" = "short <key> <value>"
              test "$(${commandHookPackage}/bin/example --config x=y mcp add server)" = "anywhere <--config> <x=y> <server>"
              test "$(${commandHookPackage}/bin/example commit first -g second)" = "flag <1> <first> <second>"
              test "$(${commandHookPackage}/bin/example commit first second)" = "original <commit> <first> <second>"
              test "$(${commandHookPackage}/bin/example delegate value)" = "original <from-hook> <value>"
              test "$(${commandHookPackage}/bin/example custom --help)" = "custom help"
              test "$(${commandHookPackage}/bin/example other value)" = "original <other> <value>"
              touch "$out"
            '';

          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt.enable = true;
              deadnix.enable = true;
              deadnix.settings.noLambdaPatternNames = true;
              statix.enable = true;
              statix.settings.config = toString statixConfig;
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        }
      );
    };
}
