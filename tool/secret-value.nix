{ lib, ... }:

let
  isSecret = value: builtins.isAttrs value && value ? _secret;

  isValidSecret =
    value:
    isSecret value && builtins.attrNames value == [ "_secret" ] && builtins.isString value._secret;
in
{
  inherit isSecret isValidSecret;

  type = lib.types.addCheck (lib.types.attrsOf lib.types.str) isValidSecret;
}
