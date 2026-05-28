{ toolFactory, ... }:

final: prev:

{
  tool = toolFactory {
    pkgs = prev;
    lib = prev.lib;
  };
}
