{
  pkgs,
  unfreePkgs,
}:

let
  pathTool = import ../tool/path.nix { };
in
pathTool.mapSubdirsWithFile {
  dir = ./.;
  fileName = "default.nix";
  missingMessage = name: "package ${name} is missing default.nix";
  value = _: path: pkgs.callPackage path { };
}
