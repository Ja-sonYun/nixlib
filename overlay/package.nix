{ packageFactory, ... }:

final: prev:

packageFactory {
  pkgs = final;
  unfreePkgs = final;
}
