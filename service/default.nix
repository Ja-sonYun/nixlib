{ toolFactory }:

let
  pathTool = import ../tool/path.nix { };
  wrapService =
    service:
    {
      config,
      lib,
      pkgs,
      ...
    }@args:
    let
      tool = toolFactory args;
    in
    service (args // { inherit tool; });

  service = pathTool.mapSubdirsWithFile {
    dir = ./.;
    fileName = "default.nix";
    missingMessage = name: "service ${name} is missing default.nix";
    value = _: path: wrapService (import path);
  };
in
service
