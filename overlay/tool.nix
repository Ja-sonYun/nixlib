{ toolFactory, ... }:

_final: prev:

{
  tool = toolFactory {
    pkgs = prev;
    inherit (prev) lib;
  };
}
