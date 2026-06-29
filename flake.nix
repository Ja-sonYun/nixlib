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
        inherit packageFactory toolFactory;
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
          statixConfig = (pkgs.formats.toml { }).generate "statix.toml" {
            disabled = [ "repeated_keys" ];
          };
        in
        {
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
