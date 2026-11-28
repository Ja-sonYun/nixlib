args:

let
  toolArgs = args // {
    inherit tool;
  };
  tool = {
    attr = import ./attr.nix toolArgs;
    text = import ./text.nix toolArgs;
    path = import ./path.nix toolArgs;
    secret = import ./secret toolArgs;
    shell = import ./shell toolArgs;
  };
in
tool
