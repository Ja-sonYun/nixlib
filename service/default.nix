{ toolFactory }:

let
  pathTool = import ../tool/path.nix { };
  wrapService =
    path:
    {
      config,
      lib,
      pkgs,
      ...
    }@args:
    let
      service = import path;
      tool = toolFactory args;
    in
    { _file = path; } // service (args // { inherit tool; });

  service = pathTool.mapSubdirsWithFile {
    dir = ./.;
    fileName = "default.nix";
    missingMessage = name: "service ${name} is missing default.nix";
    value = _: wrapService;
  };
in
service
