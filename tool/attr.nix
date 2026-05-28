{ lib, ... }:

with lib;

let
  pruneEmptyAttrs =
    value:
    if isAttrs value then
      let
        pruned = mapAttrs (_: pruneEmptyAttrs) value;
      in
      filterAttrs (_: value: value != null && value != { }) pruned
    else if builtins.isList value then
      map pruneEmptyAttrs value
    else
      value;
in
{
  /**
    Remove empty values from an attribute set.

    This is mainly used when building launchd plists, where null or empty
    values should be omitted instead of rendered.
  */
  nonEmptyAttrs = attrs: filterAttrs (_: value: value != null && value != { } && value != [ ]) attrs;

  /**
    Recursively remove null and empty attribute set values from an attribute set.

    Lists are traversed, but list items are not removed.
  */
  inherit pruneEmptyAttrs;
}
