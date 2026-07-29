args:

let
  toolArgs = args // {
    inherit tool;
  };
  tool = {
    attr = import ./attr.nix toolArgs;
    text = import ./text.nix toolArgs;
    path = import ./path.nix toolArgs;
    secretSettings = import ./secret-settings.nix toolArgs;
    shell = import ./shell toolArgs;
  };
in
tool
