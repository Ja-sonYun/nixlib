{ commandFactory, ... }:

_final: prev:

{
  command = commandFactory {
    pkgs = prev;
    inherit (prev) lib;
  };
}
