{
  description = "A collection of nix utilities";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      toolFactory = import ./tool;
      serviceModules =
        { ... }:
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
    };
}
