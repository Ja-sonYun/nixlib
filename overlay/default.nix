args:

{
  package = import ./package.nix args;
  tool = import ./tool.nix args;
}
